from typing import Optional

from aws_cdk import (
    Stack,
    aws_ec2 as ec2,
)
from constructs import Construct

from .database import KeycloakDatabase
from .service import KeycloakService
from .config import KeycloakConfig
from .url import KeycloakUrl


class KeycloakStack(Stack):

    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        is_production: bool,
        hostname: str,
        ssl_certificate_arn: str,
        keycloak_version: str,
        keycloak_app_dir: str,
        keycloak_config_cli_version: str,
        keycloak_config_cli_app_dir: str,
        idp_oauth_client_secrets: dict,
        private_oauth_clients: list,
        configure_route53: bool,
        hosted_zone_domain: Optional[str] = None,
        vpc_id: Optional[str] = None,
        rds_snapshot_identifier: Optional[str] = None,
        stage: str = "dev",
        saml_secrets: Optional[dict] = None,
        sso_email_whitelist: str = "",
        ecs_cpu: int = 512,
        ecs_memory_mib: int = 1024,
        ecs_health_check_grace_period: int = 120,
        rds_instance_class: str = "BURSTABLE4_GRAVITON",
        rds_instance_size: str = "SMALL",
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        vpc = (
            ec2.Vpc.from_lookup(self, "Vpc", vpc_id=vpc_id)
            if vpc_id
            else ec2.Vpc(self, "vpc")
        )

        kc_db = KeycloakDatabase(
            self,
            "database",
            vpc=vpc,
            database_name="keycloak",
            is_production=is_production,
            snapshot_identifier=rds_snapshot_identifier,
            instance_class=rds_instance_class,
            instance_size=rds_instance_size,
        )

        kc_service = KeycloakService(
            self,
            "service",
            vpc=vpc,
            database_name=kc_db.database_name,
            database_instance=kc_db.database,
            app_dir=keycloak_app_dir,
            version=keycloak_version,
            hostname=hostname,
            ssl_certificate_arn=ssl_certificate_arn,
            sso_email_whitelist=sso_email_whitelist,
            cpu=ecs_cpu,
            memory_limit_mib=ecs_memory_mib,
            health_check_grace_period_seconds=ecs_health_check_grace_period,
        )

        KeycloakConfig(
            self,
            "config",
            cluster=kc_service.alb_service.cluster,
            security_group_ids=[
                sg.security_group_id
                for sg in kc_service.alb_service.service.connections.security_groups
            ],
            hostname=hostname,
            subnet_ids=[subnet.subnet_id for subnet in vpc.public_subnets],
            admin_secret=kc_service.admin_secret,
            app_dir=keycloak_config_cli_app_dir,
            idp_oauth_client_secrets=idp_oauth_client_secrets,
            private_oauth_clients=private_oauth_clients,
            version=keycloak_config_cli_version,
            stage=stage,
            saml_secrets=saml_secrets,
        )

        if configure_route53:
            KeycloakUrl(
                self,
                "url",
                hostname=hostname,
                alb=kc_service.alb_service.load_balancer,
                hosted_zone_domain=hosted_zone_domain,
            )
        else:
            print("Warning: Environment is set to manual DNS configuration--new record for keycloak service load balancer must be added to hosted zone")
