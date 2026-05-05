<#-- Branded HTML email — table-based layout for broad email-client support. -->
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${msg("emailVerificationSubject")}</title>
</head>
<body style="margin:0;padding:0;background-color:#f5f5f5;font-family:'Frutiger','Frutiger LT Std','Helvetica Neue',Helvetica,Arial,sans-serif;color:#1a1a1a;-webkit-font-smoothing:antialiased;">

    <#-- Outer wrapper carries the gradient (with solid bgcolor fallback for clients that strip background-image). -->
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
           bgcolor="#f5f5f5"
           style="background-color:#f5f5f5;background-image:linear-gradient(to top left, rgba(0,98,155,0.05) 0%, #f5f5f5 20%, rgba(0,98,155,0.1) 100%);">
        <tr>
            <td align="center" style="padding:32px 16px 0;">

                <#-- ===== Logo ===== -->
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="max-width:600px;">
                    <tr>
                        <td align="center" style="padding:8px 0 24px;">
                            <img src="${url.resourcesUrl}/img/GRSS-lightmode-logo.png"
                                 width="160" alt="GRSS"
                                 style="display:block;border:0;outline:none;text-decoration:none;height:auto;max-width:160px;">
                        </td>
                    </tr>
                </table>

                <#-- ===== Card ===== -->
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="max-width:600px;background:#ffffff;border:1px solid rgba(0,0,0,0.1);border-radius:10px;box-shadow:0 1px 3px rgba(0,0,0,0.06);">
                    <tr>
                        <td style="padding:32px;">
                            <p style="margin:0 0 16px;font-size:15px;font-weight:500;color:#1a1a1a;line-height:1.5;">
                                Hi ${(user.email)!''},
                            </p>
                            <p style="margin:0 0 24px;font-size:15px;line-height:1.5;color:#1a1a1a;">
                                Someone has created a ${realmName} account with this email address. If this was you, click the button below to verify your email address.
                            </p>

                            <#-- CTA button -->
                            <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" style="margin:0 auto 24px;">
                                <tr>
                                    <td align="center" bgcolor="#00629b" style="border-radius:10px;">
                                        <a href="${link}" target="_blank"
                                           style="display:inline-block;padding:12px 28px;font-family:'Frutiger','Frutiger LT Std','Helvetica Neue',Helvetica,Arial,sans-serif;font-size:15px;font-weight:500;color:#ffffff;text-decoration:none;border-radius:10px;">
                                            Verify email address
                                        </a>
                                    </td>
                                </tr>
                            </table>

                            <p style="margin:0 0 16px;font-size:13px;line-height:1.5;color:#717182;">
                                Or paste this link into your browser:<br>
                                <a href="${link}" style="color:#00629b;text-decoration:none;word-break:break-all;">${link}</a>
                            </p>

                            <p style="margin:24px 0 0;padding-top:16px;border-top:1px solid rgba(0,0,0,0.1);font-size:13px;line-height:1.5;color:#717182;">
                                This link will expire within ${linkExpiration} minutes. If you didn't create this account, you can safely ignore this message.
                            </p>
                        </td>
                    </tr>
                </table>

                <#-- spacer -->
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="max-width:600px;">
                    <tr><td height="32" style="height:32px;line-height:32px;font-size:0;">&nbsp;</td></tr>
                </table>

            </td>
        </tr>

        <#-- ===== Footer ===== -->
        <tr>
            <td align="center" bgcolor="#ffffff"
                style="background:#ffffff;border-top:1px solid rgba(0,0,0,0.1);padding:24px;font-family:'Frutiger','Frutiger LT Std','Helvetica Neue',Helvetica,Arial,sans-serif;color:#1a1a1a;">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" style="max-width:600px;">
                    <tr>
                        <td valign="middle" style="padding-right:16px;">
                            <img src="${url.resourcesUrl}/img/IEEE%20GRSS.jpg"
                                 width="120" height="32" alt="IEEE GRSS"
                                 style="display:block;border:0;outline:none;text-decoration:none;height:auto;max-width:120px;">
                        </td>
                        <td valign="middle" style="font-size:10px;line-height:1.5;color:#717182;text-align:left;">
                            &copy; Copyright 2025 IEEE &ndash; All rights reserved. A public charity, IEEE is the world&rsquo;s largest technical professional organization dedicated to advancing technology for the benefit of humanity.
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
