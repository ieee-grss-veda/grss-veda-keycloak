package org.nasa.impact.keycloak.authenticator;

import org.keycloak.Config;
import org.keycloak.authentication.Authenticator;
import org.keycloak.authentication.AuthenticatorFactory;
import org.keycloak.models.AuthenticationExecutionModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.KeycloakSessionFactory;
import org.keycloak.provider.ProviderConfigProperty;

import java.util.List;

public class EmailWhitelistAuthenticatorFactory implements AuthenticatorFactory {

    public static final String PROVIDER_ID = "email-whitelist";
    public static final String CONFIG_EMAIL_WHITELIST = "emailWhitelist";
    private static final EmailWhitelistAuthenticator SINGLETON = new EmailWhitelistAuthenticator();

    @Override
    public String getId() {
        return PROVIDER_ID;
    }

    @Override
    public String getDisplayType() {
        return "Email Whitelist Check";
    }

    @Override
    public String getReferenceCategory() {
        return "authorization";
    }

    @Override
    public String getHelpText() {
        return "Checks the user's email against a configurable whitelist managed via the Admin Console. "
                + "Supports exact emails and domain wildcards (*@domain). "
                + "If the whitelist is empty or not configured, all users are allowed.";
    }

    @Override
    public boolean isConfigurable() {
        return true;
    }

    @Override
    public boolean isUserSetupAllowed() {
        return false;
    }

    @Override
    public AuthenticationExecutionModel.Requirement[] getRequirementChoices() {
        return new AuthenticationExecutionModel.Requirement[]{
                AuthenticationExecutionModel.Requirement.REQUIRED,
                AuthenticationExecutionModel.Requirement.DISABLED
        };
    }

    @Override
    public Authenticator create(KeycloakSession session) {
        return SINGLETON;
    }

    @Override
    public List<ProviderConfigProperty> getConfigProperties() {
        ProviderConfigProperty whitelistProp = new ProviderConfigProperty();
        whitelistProp.setName(CONFIG_EMAIL_WHITELIST);
        whitelistProp.setLabel("Email Whitelist");
        whitelistProp.setType(ProviderConfigProperty.STRING_TYPE);
        whitelistProp.setHelpText(
                "Comma-separated list of allowed email addresses or domain wildcards. "
                + "Example: user@example.com,*@nasa.gov. "
                + "If empty, all users are allowed.");
        return List.of(whitelistProp);
    }

    @Override
    public void init(Config.Scope config) {
    }

    @Override
    public void postInit(KeycloakSessionFactory factory) {
    }

    @Override
    public void close() {
    }
}
