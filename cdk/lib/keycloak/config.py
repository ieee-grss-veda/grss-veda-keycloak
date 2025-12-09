import json
import textwrap
from pathlib import Path

from aws_cdk import (
    Duration,
    CfnOutput,
    Stack,
    aws_ecr_assets as ecr_assets,
    aws_ecs as ecs,
    aws_iam as iam,
    aws_lambda as _lambda,
    aws_secretsmanager as secretsmanager,
)
from constructs import Construct


class KeycloakConfig(Construct):
    """
    Responsible for creating infrastructure to apply configuration to a Keycloak instance.
    """

    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        cluster: ecs.ICluster,
        security_group_ids: list[str],
        subnet_ids: list[str],
        admin_secret: secretsmanager.ISecret,
        hostname: str,
        app_dir: str,
        idp_oauth_client_secrets: dict[str, str],
        private_oauth_clients: list[dict[str, str]],
        version: str,
        stage: str = "dev",
        saml_secrets: dict[str, str] | None = None,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Ensure hostname has https:// prefix for OAuth client URLs
        public_url = hostname if hostname.startswith("http") else f"https://{hostname}"

        # Create a client secret for each private OAuth client
        created_client_secrets = []
        for client_info in private_oauth_clients:
            client_slug = client_info["id"]
            realm = client_info["realm"]
            secret = secretsmanager.Secret(
                self,
                f"{client_slug}-client-secret",
                # WARNING: Changing this construct (name, id, template) will cause new client
                # secrets to be generated!
                secret_name=f"{Stack.of(self).stack_name}-client-{client_slug}",
                generate_secret_string=secretsmanager.SecretStringGenerator(
                    exclude_punctuation=True,
                    include_space=False,
                    secret_string_template=json.dumps(
                        {
                            "id": client_slug,
                            "auth_url": f"{public_url}/realms/{realm}/protocol/openid-connect/auth",
                            "token_url": f"{public_url}/realms/{realm}/protocol/openid-connect/token",
                            "userinfo_url": f"{public_url}/realms/{realm}/protocol/openid-connect/userinfo",
                        },
                        separators=(",", ":"),
                    ),
                    generate_string_key="secret",
                    password_length=16,
                ),
            )
            created_client_secrets.append((client_slug, secret))

        # Import the client secrets for each public clients
        imported_client_secrets = []
        for client_slug, secret_arn in idp_oauth_client_secrets.items():
            imported_secret = secretsmanager.Secret.from_secret_partial_arn(
                self, f"{client_slug}-client-secret", secret_arn
            )
            imported_client_secrets.append((client_slug, imported_secret))

        # Create env vars from secrets for each client, e.g. GRAFANA_CLIENT_ID, GRAFANA_CLIENT_SECRET
        task_client_secrets = {}
        for client_slug, secret in created_client_secrets + imported_client_secrets:
            for key in ["id", "secret"]:
                # Example: GRAFANA_CLIENT_ID or GRAFANA_CLIENT_SECRET
                env_var = f"{client_slug.replace('-', '_')}_CLIENT_{key}".upper()
                task_client_secrets[env_var] = ecs.Secret.from_secrets_manager(
                    secret, key
                )

        # Determine IMPORT_FILES_LOCATIONS based on available config files
        # Base files are always included, environment-specific files are added if they exist
        config_dir = Path(app_dir) / "config"

        import_files = ["/config/master.yaml"]
        if (config_dir / f"master.{stage}.yaml").exists():
            import_files.append(f"/config/master.{stage}.yaml")

        import_files.append("/config/veda.yaml")
        if (config_dir / f"veda.{stage}.yaml").exists():
            import_files.append(f"/config/veda.{stage}.yaml")

        import_files_locations = ",".join(import_files)

        # Import SAML secrets if provided (for staging/prod)
        saml_task_secrets = {}
        if saml_secrets:
            for secret_key, secret_arn in saml_secrets.items():
                imported_secret = secretsmanager.Secret.from_secret_partial_arn(
                    self, f"saml-{secret_key}", secret_arn
                )
                # Map secret fields to environment variables
                # Expected secret structure: idpEntityId, ssoUrl, sloUrl, signingCertificate, displayName
                secret_field_mappings = {
                    "SAML": {
                        "idpEntityId": "SAML_IDP_ENTITY_ID",
                        "ssoUrl": "SAML_SSO_URL",
                        "sloUrl": "SAML_SLO_URL",
                        "signingCertificate": "SAML_SIGNING_CERTIFICATE",
                        "displayName": "SAML_IDP_DISPLAY_NAME",
                    },
                    "VEDA_SAML": {
                        "idpEntityId": "VEDA_SAML_IDP_ENTITY_ID",
                        "ssoUrl": "VEDA_SAML_SSO_URL",
                        "sloUrl": "VEDA_SAML_SLO_URL",
                        "signingCertificate": "VEDA_SAML_SIGNING_CERTIFICATE",
                        "displayName": "VEDA_SAML_IDP_DISPLAY_NAME",
                    },
                }
                if secret_key in secret_field_mappings:
                    for field, env_var in secret_field_mappings[secret_key].items():
                        saml_task_secrets[env_var] = ecs.Secret.from_secrets_manager(
                            imported_secret, field
                        )

        config_task_def = ecs.FargateTaskDefinition(
            self, "ConfigTaskDef", cpu=256, memory_limit_mib=512
        )
        container_name = "ConfigContainer"
        config_task_def.add_container(
            container_name,
            container_name=container_name,
            image=ecs.ContainerImage.from_asset(
                directory=app_dir,
                platform=ecr_assets.Platform.LINUX_AMD64,
                build_args={"KEYCLOAK_CONFIG_CLI_VERSION": version},
            ),
            environment={
                # Ensure HTTPS protocol is included for Keycloak URL
                "KEYCLOAK_URL": public_url,
                "KEYCLOAK_AVAILABILITYCHECK_ENABLED": "true",
                "KEYCLOAK_AVAILABILITYCHECK_TIMEOUT": "120s",
                "IMPORT_FILES_LOCATIONS": import_files_locations,
                "IMPORT_CACHE_ENABLED": "false",
                "IMPORT_VARSUBSTITUTION_ENABLED": "true",
            },
            logging=ecs.LogDrivers.aws_logs(stream_prefix="KeycloakConfig"),
            secrets={
                "KEYCLOAK_USER": ecs.Secret.from_secrets_manager(
                    admin_secret, "username"
                ),
                "KEYCLOAK_PASSWORD": ecs.Secret.from_secrets_manager(
                    admin_secret, "password"
                ),
                **task_client_secrets,  # Merge the generated client secrets
                **saml_task_secrets,  # Merge SAML secrets for staging/prod
            },
        )

        # Explicitly grant GetSecretValue permission for imported IdP secrets
        if imported_client_secrets:
            idp_secret_arns = [secret.secret_arn for _, secret in imported_client_secrets]
            config_task_def.execution_role.add_to_policy(
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "secretsmanager:GetSecretValue",
                        "secretsmanager:DescribeSecret",
                    ],
                    resources=idp_secret_arns,
                )
            )

        # Grant GetSecretValue permission for SAML secrets (staging/prod)
        if saml_secrets:
            config_task_def.execution_role.add_to_policy(
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "secretsmanager:GetSecretValue",
                        "secretsmanager:DescribeSecret",
                    ],
                    resources=list(saml_secrets.values()),
                )
            )

        # Helper to simplify triggering the ECS task
        code = f"""
            const {{ ECSClient, RunTaskCommand }} = require('@aws-sdk/client-ecs');

            const ecsClient = new ECSClient({{}});

            exports.handler = async function(event) {{
                console.log('Received event:', event);
                const params = {{
                    cluster: "{cluster.cluster_name}",
                    taskDefinition: "{config_task_def.task_definition_arn}",
                    launchType: 'FARGATE',
                    overrides: {{
                        containerOverrides: [
                            {{
                                name: "{container_name}",
                                environment: Object.entries(event).map(([name, value]) => ({{
                                name,
                                value: String(value),
                                }})),
                            }},
                        ],
                    }},
                    networkConfiguration: {{
                        awsvpcConfiguration: {{
                            subnets: {json.dumps(subnet_ids)},
                            securityGroups: {json.dumps(security_group_ids)},
                            assignPublicIp: 'ENABLED',
                        }},
                    }},
                }};

                try {{
                    const result = await ecsClient.send(new RunTaskCommand(params));
                    console.log('ECS RunTask result:', result);
                    const {{ taskArn, clusterArn }} = result.tasks[0];
                    return {{ taskArn, clusterArn }};
                }} catch (error) {{
                    console.error('Error running ECS task:', error);
                    throw new Error('Failed to start ECS task');
                }}
            }};
        """
        apply_config_lambda = _lambda.Function(
            self,
            "ApplyConfigLambda",
            code=_lambda.Code.from_inline(textwrap.dedent(code).strip()),
            handler="index.handler",
            runtime=_lambda.Runtime.NODEJS_LATEST,
            timeout=Duration.minutes(5),
        )

        config_task_def.grant_run(apply_config_lambda)

        CfnOutput(
            self,
            "ConfigLambdaArn",
            key="ConfigLambdaArn",
            value=apply_config_lambda.function_arn,
        )
