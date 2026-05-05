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
    for (var i = 0; i < existing.length; i++)
      existing[i].parentNode.removeChild(existing[i]);

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

  var logoUrl = resolveResourceUrl('img/IEEE%20GRSS.jpg');

  var footerHtml = [
    '<footer class="veda-footer" role="contentinfo">',
    '  <div class="veda-footer__container">',
    '    <img class="veda-footer__logo" src="' + logoUrl + '" alt="IEEE GRSS">',
    '    <p class="veda-footer__copy">© Copyright 2025 IEEE – All rights reserved. A public charity, IEEE is the world’s largest technical professional organization dedicated to advancing technology for the benefit of humanity.</p>',

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
