package org.nasa.impact.keycloak.authenticator;

import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.AuthenticationFlowError;
import org.keycloak.authentication.Authenticator;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;

import jakarta.ws.rs.core.Response;
import java.util.ArrayList;
import java.util.List;

import org.jboss.logging.Logger;

public class EmailWhitelistAuthenticator implements Authenticator {

    private static final Logger logger = Logger.getLogger(EmailWhitelistAuthenticator.class);
    static final String ENV_VAR_NAME = "SSO_EMAIL_WHITELIST";

    @Override
    public void authenticate(AuthenticationFlowContext context) {
        String whitelist = System.getenv(ENV_VAR_NAME);

        if (whitelist == null || whitelist.trim().isEmpty()) {
            logger.debug("SSO_EMAIL_WHITELIST not set, allowing all users");
            context.success();
            return;
        }

        UserModel user = context.getUser();
        if (user == null) {
            logger.warn("Email whitelist check: no user in context, denying access");
            deny(context, "emailWhitelistDenied");
            return;
        }

        String userEmail = user.getEmail();
        if (userEmail == null || userEmail.trim().isEmpty()) {
            logger.warnf("Email whitelist check: user '%s' has no email, denying access",
                    user.getUsername());
            deny(context, "emailWhitelistNoEmail");
            return;
        }

        List<String> entries = parseWhitelist(whitelist);
        String emailLower = userEmail.trim().toLowerCase();

        if (isEmailWhitelisted(emailLower, entries)) {
            logger.infof("Email whitelist check: user '%s' (%s) is whitelisted",
                    user.getUsername(), userEmail);
            context.success();
        } else {
            logger.warnf("Email whitelist check: user '%s' (%s) is NOT whitelisted",
                    user.getUsername(), userEmail);
            deny(context, "emailWhitelistDenied");
        }
    }

    private void deny(AuthenticationFlowContext context, String errorMessage) {
        Response challenge = context.form()
                .setError(errorMessage)
                .createErrorPage(Response.Status.FORBIDDEN);
        context.failure(AuthenticationFlowError.ACCESS_DENIED, challenge);
    }

    private List<String> parseWhitelist(String whitelist) {
        List<String> entries = new ArrayList<>();
        for (String entry : whitelist.split(",")) {
            String trimmed = entry.trim().toLowerCase();
            if (!trimmed.isEmpty()) {
                entries.add(trimmed);
            }
        }
        return entries;
    }

    private boolean isEmailWhitelisted(String email, List<String> entries) {
        for (String entry : entries) {
            if (entry.startsWith("*@")) {
                String domain = entry.substring(1); // "@example.com"
                if (email.endsWith(domain)) {
                    return true;
                }
            } else if (email.equals(entry)) {
                return true;
            }
        }
        return false;
    }

    @Override
    public void action(AuthenticationFlowContext context) {
        // Not used - this authenticator does not present a form
    }

    @Override
    public boolean requiresUser() {
        return true;
    }

    @Override
    public boolean configuredFor(KeycloakSession session, RealmModel realm, UserModel user) {
        return true;
    }

    @Override
    public void setRequiredActions(KeycloakSession session, RealmModel realm, UserModel user) {
        // No required actions
    }

    @Override
    public void close() {
        // Nothing to clean up
    }
}
