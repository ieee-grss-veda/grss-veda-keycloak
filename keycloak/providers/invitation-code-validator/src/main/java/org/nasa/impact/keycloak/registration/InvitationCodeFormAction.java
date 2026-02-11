package org.nasa.impact.keycloak.registration;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.keycloak.authentication.FormAction;
import org.keycloak.authentication.FormContext;
import org.keycloak.authentication.ValidationContext;
import org.keycloak.events.Details;
import org.keycloak.events.Errors;
import org.keycloak.forms.login.LoginFormsProvider;
import org.keycloak.models.GroupModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;
import org.keycloak.models.utils.FormMessage;
import org.keycloak.services.validation.Validation;

import jakarta.ws.rs.core.MultivaluedMap;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * FormAction that validates invitation codes during user registration.
 * Reads invitation codes from realm attributes and assigns users to groups based on the code used.
 */
public class InvitationCodeFormAction implements FormAction {

    private static final String INVITATION_CODE_FIELD = "invitationCode";
    private static final String INVITATION_CODES_ATTRIBUTE = "invitation_codes";
    private static final String USER_TYPE_ATTRIBUTE = "user_type";
    private static final String SESSION_NOTE_GROUP_NAME = "invitation_code_group";

    @Override
    public void buildPage(FormContext context, LoginFormsProvider form) {
        // The form template will include the invitation code field
        // No additional page building needed
    }

    @Override
    public void validate(ValidationContext context) {
        MultivaluedMap<String, String> formData = context.getHttpRequest().getDecodedFormParameters();
        List<FormMessage> errors = new ArrayList<>();

        String invitationCode = formData.getFirst(INVITATION_CODE_FIELD);

        // Check if invitation code is provided
        if (Validation.isBlank(invitationCode)) {
            errors.add(new FormMessage(INVITATION_CODE_FIELD, "missingInvitationCodeMessage"));
            context.error(Errors.INVALID_REGISTRATION);
            context.validationError(formData, errors);
            return;
        }

        // Retrieve invitation codes from realm attributes
        RealmModel realm = context.getRealm();
        String invitationCodesJson = realm.getAttribute(INVITATION_CODES_ATTRIBUTE);

        if (invitationCodesJson == null || invitationCodesJson.trim().isEmpty()) {
            context.error(Errors.INVALID_REGISTRATION);
            errors.add(new FormMessage(INVITATION_CODE_FIELD, "invalidInvitationCodeMessage"));
            context.validationError(formData, errors);
            return;
        }

        // Parse JSON to find matching invitation code
        Map<String, InvitationCodeConfig> codes;
        try {
            codes = parseInvitationCodes(invitationCodesJson);
        } catch (Exception e) {
            context.error(Errors.INVALID_REGISTRATION);
            errors.add(new FormMessage(INVITATION_CODE_FIELD, "invalidInvitationCodeMessage"));
            context.validationError(formData, errors);
            return;
        }

        InvitationCodeConfig codeConfig = codes.get(invitationCode);

        if (codeConfig == null || !codeConfig.isEnabled()) {
            context.error(Errors.INVALID_REGISTRATION);
            errors.add(new FormMessage(INVITATION_CODE_FIELD, "invalidInvitationCodeMessage"));
            context.validationError(formData, errors);
            return;
        }

        // Store the group assignment for the success handler
        context.getAuthenticationSession().setUserSessionNote(SESSION_NOTE_GROUP_NAME, codeConfig.getGroupName());
        context.success();
    }

    @Override
    public void success(FormContext context) {
        UserModel user = context.getUser();

        // Get the group name from session notes
        String groupName = context.getAuthenticationSession().getUserSessionNote(SESSION_NOTE_GROUP_NAME);

        if (groupName != null && !groupName.isEmpty()) {
            // Find and add user to the group
            GroupModel group = context.getRealm().getGroupsStream()
                    .filter(g -> g.getName().equals(groupName))
                    .findFirst()
                    .orElse(null);

            if (group != null) {
                user.joinGroup(group);
                context.getEvent().detail("assigned_group", groupName);
            }
        }

        // Mark user as guest user via attribute
        user.setSingleAttribute(USER_TYPE_ATTRIBUTE, "guest");
    }

    @Override
    public boolean requiresUser() {
        return false;
    }

    @Override
    public boolean configuredFor(KeycloakSession session, RealmModel realm, UserModel user) {
        return true;
    }

    @Override
    public void setRequiredActions(KeycloakSession session, RealmModel realm, UserModel user) {
        // No required actions needed
    }

    @Override
    public void close() {
        // No cleanup needed
    }

    /**
     * Helper method to parse invitation codes JSON from realm attributes.
     *
     * @param json JSON string containing invitation code configurations
     * @return Map of invitation code to configuration
     * @throws Exception if JSON parsing fails
     */
    private Map<String, InvitationCodeConfig> parseInvitationCodes(String json) throws Exception {
        ObjectMapper mapper = new ObjectMapper();
        return mapper.readValue(json, new TypeReference<Map<String, InvitationCodeConfig>>() {});
    }

    /**
     * Configuration for an invitation code.
     */
    public static class InvitationCodeConfig {
        private String groupName;
        private boolean enabled;
        private String description;

        public InvitationCodeConfig() {
        }

        public String getGroupName() {
            return groupName;
        }

        public void setGroupName(String groupName) {
            this.groupName = groupName;
        }

        public boolean isEnabled() {
            return enabled;
        }

        public void setEnabled(boolean enabled) {
            this.enabled = enabled;
        }

        public String getDescription() {
            return description;
        }

        public void setDescription(String description) {
            this.description = description;
        }
    }
}
