<#import "template.ftl" as layout>
<@layout.registrationLayout displayInfo=false; section>
    <#if section = "header">
        ${msg("emailVerifyTitle")}
    <#elseif section = "form">
        <div class="kc-verify-email">
            <p class="kc-verify-email__greeting">Hi ${(user.email)!''},</p>
            <p class="kc-verify-email__body">${msg("emailVerifyInstruction1",(user.email)!'')}</p>
            <p class="kc-verify-email__resend">
                ${msg("emailVerifyInstruction2")}
                <a href="${url.loginAction}">${msg("doClickHere")}</a> ${msg("emailVerifyInstruction3")}
            </p>
        </div>
    </#if>
</@layout.registrationLayout>
