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
    private static final String SESSION_NOTE_GROUP_NAMES = "invitation_code_groups";

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

        // Store the group assignments for the success handler
        List<String> groups = codeConfig.getResolvedGroupNames();
        context.getAuthenticationSession().setAuthNote(SESSION_NOTE_GROUP_NAMES, String.join(",", groups));
        context.success();
    }

    @Override
    public void success(FormContext context) {
        UserModel user = context.getUser();

        // Get the group names from session notes (comma-separated)
        String groupNamesRaw = context.getAuthenticationSession().getAuthNote(SESSION_NOTE_GROUP_NAMES);

        if (groupNamesRaw != null && !groupNamesRaw.isEmpty()) {
            List<String> assignedGroups = new ArrayList<>();
            for (String rawName : groupNamesRaw.split(",")) {
                String groupName = rawName.trim();
                if (groupName.isEmpty()) continue;

                GroupModel group = context.getRealm().getGroupsStream()
                        .filter(g -> g.getName().equals(groupName))
                        .findFirst()
                        .orElse(null);

                if (group != null) {
                    user.joinGroup(group);
                    assignedGroups.add(groupName);
                }
            }
            if (!assignedGroups.isEmpty()) {
                context.getEvent().detail("assigned_groups", String.join(",", assignedGroups));
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
     * Supports both "groupNames" (array) and legacy "groupName" (string).
     */
    public static class InvitationCodeConfig {
        private String groupName;
        private List<String> groupNames;
        private boolean enabled;
        private String description;

        public InvitationCodeConfig() {
        }

        /**
         * Returns the resolved list of group names.
         * Prefers "groupNames" if set, falls back to "groupName" for backward compatibility.
         */
        public List<String> getResolvedGroupNames() {
            if (groupNames != null && !groupNames.isEmpty()) {
                return groupNames;
            }
            if (groupName != null && !groupName.isEmpty()) {
                return List.of(groupName);
            }
            return List.of();
        }

        public String getGroupName() {
            return groupName;
        }

        public void setGroupName(String groupName) {
            this.groupName = groupName;
        }

        public List<String> getGroupNames() {
            return groupNames;
        }

        public void setGroupNames(List<String> groupNames) {
            this.groupNames = groupNames;
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
