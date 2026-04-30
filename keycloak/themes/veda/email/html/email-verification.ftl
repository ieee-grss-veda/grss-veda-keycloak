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

        <#-- ===== Footer (mirrors footer.js output) ===== -->
        <tr>
            <td align="center" bgcolor="#ffffff"
                style="background:#ffffff;border-top:1px solid rgba(0,0,0,0.1);padding:32px 24px;font-family:'Frutiger','Frutiger LT Std','Helvetica Neue',Helvetica,Arial,sans-serif;color:#1a1a1a;">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="max-width:1100px;">
                    <tr>
                        <#-- Left column: GRSS logo -->
                        <td align="left" valign="middle" width="20%" style="padding:12px;">
                            <img src="https://www.grss-ieee.org/wp-content/uploads/2020/11/grss-logo.png"
                                 width="150" height="99" alt="GRSS IEEE"
                                 style="display:block;border:0;outline:none;text-decoration:none;height:auto;max-width:150px;">
                        </td>

                        <#-- Center column: nav + copyright -->
                        <td align="center" valign="middle" width="60%" style="padding:12px;">
                            <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center">
                                <tr>
                                    <td align="center" style="font-size:13px;line-height:1.9;color:#1a1a1a;">
                                        <a href="https://www.grss-ieee.org/" style="color:#1a1a1a;text-decoration:none;font-weight:500;margin:0 8px;">Home</a>
                                        <a href="http://www.ieee.org/sitemap.html" style="color:#1a1a1a;text-decoration:none;font-weight:500;margin:0 8px;">Sitemap/More Sites</a>
                                        <a href="https://www.grss-ieee.org/contact-us/" style="color:#1a1a1a;text-decoration:none;font-weight:500;margin:0 8px;">Contact</a>
                                        <a href="https://www.ieee.org/accessibility-statement.html" style="color:#1a1a1a;text-decoration:none;font-weight:500;margin:0 8px;">Accessibility</a>
                                        <a href="http://www.ieee.org/accessibility_statement.html" style="color:#1a1a1a;text-decoration:none;font-weight:500;margin:0 8px;">Nondiscrimination Policy</a>
                                        <a href="http://ieee-ethics-reporting.org/" style="color:#1a1a1a;text-decoration:none;font-weight:500;margin:0 8px;">IEEE Ethics Reporting</a>
                                        <a href="http://www.ieee.org/security_privacy.html" style="color:#1a1a1a;text-decoration:none;font-weight:500;margin:0 8px;">IEEE Privacy Policy</a>
                                        <a href="https://www.ieee.org/about/help/site-terms-conditions.html" style="color:#1a1a1a;text-decoration:none;font-weight:500;margin:0 8px;">Terms &amp; Disclosures</a>
                                    </td>
                                </tr>
                                <tr>
                                    <td align="center" style="padding-top:12px;">
                                        <p style="margin:0;font-size:12px;line-height:1.5;color:#717182;max-width:540px;">
                                            &copy; Copyright 2025 IEEE &ndash; All rights reserved. A public charity, IEEE is the world&rsquo;s largest technical professional organization dedicated to advancing technology for the benefit of humanity.
                                        </p>
                                    </td>
                                </tr>
                            </table>
                        </td>

                        <#-- Right column: IEEE logo -->
                        <td align="right" valign="middle" width="20%" style="padding:12px;">
                            <img src="https://www.grss-ieee.org/wp-content/uploads/2020/11/ieee-logo.png"
                                 width="150" height="53" alt=""
                                 style="display:block;border:0;outline:none;text-decoration:none;height:auto;max-width:150px;margin-left:auto;">
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
