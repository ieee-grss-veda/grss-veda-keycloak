(function () {
  var SITE_TITLE = 'GRSS VEDA';

  function resolveResourceUrl(relativePath) {
    var script = document.currentScript;
    if (!script) {
      var scripts = document.getElementsByTagName('script');
      for (var i = 0; i < scripts.length; i++) {
        if (scripts[i].src && scripts[i].src.indexOf('/js/footer.js') !== -1) {
          script = scripts[i];
          break;
        }
      }
    }
    if (!script || !script.src) return relativePath;
    return script.src.replace(/\/js\/footer\.js(\?.*)?$/, '/' + relativePath);
  }

  function ensureFavicon() {
    var existing = document.querySelectorAll('link[rel~="icon"]');
    for (var i = 0; i < existing.length; i++) existing[i].parentNode.removeChild(existing[i]);

    var iconUrl = resolveResourceUrl('img/favicon.ico');
    var head = document.head || document.getElementsByTagName('head')[0];
    if (!head) return;

    var iconLink = document.createElement('link');
    iconLink.rel = 'icon';
    iconLink.type = 'image/x-icon';
    iconLink.href = iconUrl;
    head.appendChild(iconLink);

    var shortcut = document.createElement('link');
    shortcut.rel = 'shortcut icon';
    shortcut.type = 'image/x-icon';
    shortcut.href = iconUrl;
    head.appendChild(shortcut);
  }

  function setTitle() {
    if (document.title !== SITE_TITLE) document.title = SITE_TITLE;
  }

  ensureFavicon();
  setTitle();

  var footerHtml = [
    '<footer class="veda-footer" role="contentinfo">',
    '  <div class="veda-footer__container">',
    '    <div class="veda-footer__column veda-footer__column--logo">',
    '      <img class="veda-footer__logo veda-footer__logo--grss"',
    '           src="https://www.grss-ieee.org/wp-content/uploads/2020/11/grss-logo.png"',
    '           srcset="https://www.grss-ieee.org/wp-content/uploads/2020/11/grss-logo.png 300w, https://www.grss-ieee.org/wp-content/uploads/2020/11/grss-logo.png 347w"',
    '           sizes="(max-width: 300px) 100vw, 300px"',
    '           width="300" height="198" alt="GRSS IEEE">',
    '    </div>',
    '    <div class="veda-footer__column veda-footer__column--center">',
    '      <nav class="veda-footer__nav" aria-label="Footer">',
    '        <ul class="veda-footer__menu">',
    '          <li><a href="https://www.grss-ieee.org/">Home</a></li>',
    '          <li><a href="http://www.ieee.org/sitemap.html">Sitemap/More Sites</a></li>',
    '          <li><a href="https://www.grss-ieee.org/contact-us/">Contact</a></li>',
    '          <li><a href="https://www.ieee.org/accessibility-statement.html" target="_blank" rel="noopener">Accessibility</a></li>',
    '          <li><a href="http://www.ieee.org/accessibility_statement.html" target="_blank" rel="noopener">Nondiscrimination Policy</a></li>',
    '          <li><a href="http://ieee-ethics-reporting.org/">IEEE Ethics Reporting</a></li>',
    '          <li><a href="http://www.ieee.org/security_privacy.html" target="_blank" rel="noopener">IEEE Privacy Policy</a></li>',
    '          <li><a href="https://www.ieee.org/about/help/site-terms-conditions.html" target="_blank" rel="noopener">Terms &amp; Disclosures</a></li>',
    '        </ul>',
    '      </nav>',
    '      <p class="veda-footer__copy">© Copyright 2025 IEEE – All rights reserved. A public charity, IEEE is the world’s largest technical professional organization dedicated to advancing technology for the benefit of humanity.</p>',
    '    </div>',
    '    <div class="veda-footer__column veda-footer__column--logo veda-footer__column--right">',
    '      <img class="veda-footer__logo veda-footer__logo--ieee"',
    '           src="https://www.grss-ieee.org/wp-content/uploads/2020/11/ieee-logo.png"',
    '           srcset="https://www.grss-ieee.org/wp-content/uploads/2020/11/ieee-logo.png 300w, https://www.grss-ieee.org/wp-content/uploads/2020/11/ieee-logo.png 325w"',
    '           sizes="(max-width: 300px) 100vw, 300px"',
    '           width="300" height="105" alt="">',
    '    </div>',
    '  </div>',
    '</footer>',
  ].join('\n');

  function inject() {
    if (document.querySelector('.veda-footer')) return;
    var page = document.querySelector('.login-pf-page') || document.body;
    page.insertAdjacentHTML('afterend', footerHtml);
    document.body.classList.add('veda-has-footer');
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', inject);
  } else {
    inject();
  }
})();
