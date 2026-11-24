/* Local-only brand book. No analytics, remote requests, storage, or app data. */
(() => {
  'use strict';
  const data = window.MUGSHOT_BRAND;
  if (!data) return;
  const {brand, tokens, assets, contrast} = data;
  const byId = id => document.getElementById(id);
  const node = (tag, text, className) => {
    const element = document.createElement(tag);
    if (text !== undefined) element.textContent = text;
    if (className) element.className = className;
    return element;
  };
  const readableName = name => name.replace(/^mugshot/, '').replace(/([a-z])([A-Z])/g, '$1 $2').replace(/^./, x => x.toUpperCase());
  const sourceCopy = id => brand.copy.find(sample => sample.id === id)?.text || '';
  document.querySelectorAll('[data-version]').forEach(element => { element.textContent = brand.version; });
  document.querySelectorAll('[data-copy]').forEach(element => { element.textContent = sourceCopy(element.dataset.copy); });
  brand.positioning.principles.forEach(principle => {
    const block = node('div');
    block.append(node('h3', principle.title), node('p', principle.body));
    byId('principles').append(block);
  });
  ['creamWhite', 'espressoBrown', 'mugshotMint', 'mugshotSageText', 'roastBrown', 'sandBeige'].forEach(name => {
    const swatch = node('div', undefined, 'swatch');
    const color = node('div', undefined, 'swatch-color');
    color.style.backgroundColor = tokens.color[name];
    color.style.color = name === 'espressoBrown' || name === 'mugshotSageText' || name === 'roastBrown' ? tokens.color.foamWhite : tokens.color.espressoBrown;
    const button = node('button', tokens.color[name]);
    button.type = 'button';
    button.dataset.copyValue = tokens.color[name];
    button.setAttribute('aria-label', 'Copy ' + name + ' ' + tokens.color[name]);
    color.append(button);
    swatch.append(color, node('h3', readableName(name)), node('p', brand.color_usage[name]));
    byId('core-palette').append(swatch);
  });
  Object.entries(tokens.color).forEach(([name, value]) => {
    const row = node('tr');
    const nameCell = node('td');
    nameCell.append(node('code', name));
    row.append(nameCell, node('td', value), node('td', brand.color_usage[name]));
    byId('all-colors').append(row);
    for (const id of ['foreground', 'background']) {
      const option = node('option', readableName(name));
      option.value = name;
      byId(id).append(option);
    }
  });
  contrast.forEach(pair => {
    const row = node('tr');
    row.append(node('td', readableName(pair.foreground) + ' / ' + readableName(pair.background)), node('td', pair.ratio.toFixed(2) + ':1'), node('td', pair.normal_text ? 'Pass' : 'Fail — avoid'));
    byId('contrast-pairs').append(row);
  });
  const luminance = hex => {
    const channels = [1, 3, 5].map(index => parseInt(hex.slice(index, index + 2), 16) / 255).map(value => value <= .04045 ? value / 12.92 : ((value + .055) / 1.055) ** 2.4);
    return channels.reduce((sum, value, index) => sum + value * [.2126, .7152, .0722][index], 0);
  };
  function updateContrast() {
    const foreground = tokens.color[byId('foreground').value];
    const background = tokens.color[byId('background').value];
    const values = [luminance(foreground), luminance(background)].sort((a, b) => b - a);
    const ratio = (values[0] + .05) / (values[1] + .05);
    const normal = ratio >= 4.5 ? 'Normal text passes' : 'Normal text fails';
    const large = ratio >= 3 ? 'large text passes' : 'large text fails';
    byId('contrast-output').textContent = ratio.toFixed(2) + ':1 · ' + normal + '; ' + large + '.';
    byId('contrast-preview').style.color = foreground;
    byId('contrast-preview').style.backgroundColor = background;
  }
  byId('foreground').value = 'espressoBrown';
  byId('background').value = 'creamWhite';
  byId('foreground').addEventListener('change', updateContrast);
  byId('background').addEventListener('change', updateContrast);
  updateContrast();
  byId('type-input').addEventListener('input', event => { byId('type-preview').textContent = event.target.value || 'The little moment around it.'; });
  brand.typography.web_roles.forEach(role => {
    const row = node('div', undefined, 'type-row');
    const description = node('div');
    description.append(node('code', role.value), node('p', role.purpose));
    row.append(node('span', role.role), description);
    byId('type-scale').append(row);
  });
  assets.filter(asset => asset.kind === 'character-reference').forEach(asset => {
    const figure = node('figure');
    const picture = node('img');
    picture.src = asset.path;
    picture.alt = asset.use;
    picture.width = asset.width;
    picture.height = asset.height;
    picture.loading = 'lazy';
    const caption = node('figcaption', asset.id.replace('mugsy-', '').replace(/^./, s => s.toUpperCase()));
    figure.append(picture, caption);
    byId('mugsy-library').append(figure);
  });
  Object.entries(tokens.characterColor).forEach(([name, value]) => {
    const token = node('span', undefined, 'character-token');
    const swatch = node('i');
    swatch.setAttribute('aria-hidden', 'true');
    swatch.style.backgroundColor = value;
    token.append(swatch, node('span', readableName(name) + ' ' + value));
    byId('character-palette').append(token);
  });
  Object.entries(tokens.space).forEach(([name, value]) => {
    const row = node('div', undefined, 'spacing-row');
    const bar = node('i');
    bar.style.width = value * 4 + 'px';
    bar.setAttribute('aria-hidden', 'true');
    row.append(node('code', name + ' / ' + value), bar);
    byId('spacing-scale').append(row);
  });
  Object.entries(tokens.radius).filter(([name]) => name !== 'pill').forEach(([name, value]) => {
    const sample = node('span', undefined, 'radius-sample');
    const shape = node('i');
    shape.style.borderRadius = value + 'px';
    shape.setAttribute('aria-hidden', 'true');
    sample.append(shape, node('span', name + ' · ' + value));
    byId('radius-scale').append(sample);
  });
  brand.copy.forEach(sample => {
    const row = node('div', undefined, 'copy-row');
    const button = node('button', 'Copy', 'copy-button');
    button.type = 'button';
    button.dataset.copyValue = sample.text;
    button.setAttribute('aria-label', 'Copy ' + sample.role.toLowerCase());
    row.append(node('span', sample.role), node('p', sample.text), button);
    byId('copy-library').append(row);
  });
  brand.applications.forEach(application => {
    const link = node('a', undefined, 'application-link');
    link.href = application.path;
    const arrow = node('b', '↗');
    arrow.setAttribute('aria-hidden', 'true');
    link.append(node('span', application.name), node('small', application.format), arrow);
    byId('application-links').append(link);
  });
  assets.forEach(asset => {
    const item = node('div', undefined, 'asset-download');
    const link = node('a', asset.id);
    link.href = asset.path;
    link.download = asset.path.split('/').pop();
    item.append(link, node('span', asset.width + ' × ' + asset.height));
    byId('asset-downloads').append(item);
  });
  let toastTimer;
  function toast(message) {
    clearTimeout(toastTimer);
    byId('toast').textContent = message;
    byId('toast').classList.add('visible');
    toastTimer = setTimeout(() => byId('toast').classList.remove('visible'), 2400);
  }
  async function copy(value) {
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(value);
      } else {
        const selection = node('textarea');
        selection.value = value;
        selection.style.position = 'fixed';
        selection.style.left = '-10000px';
        document.body.append(selection);
        selection.select();
        const success = document.execCommand('copy');
        selection.remove();
        if (!success) throw new Error('Clipboard unavailable');
      }
      toast('Copied to clipboard');
    } catch {
      toast('Clipboard unavailable. The source text is selectable.');
    }
  }
  document.addEventListener('click', event => {
    const copyButton = event.target.closest('[data-copy-value]');
    if (copyButton) copy(copyButton.dataset.copyValue);
  });
  document.querySelectorAll('.sample-filters button').forEach(button => button.addEventListener('click', () => {
    document.querySelectorAll('.sample-filters button').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
    byId('component-status').textContent = button.textContent + ' selected. Local specimen only.';
  }));
  byId('motion-button').addEventListener('click', event => {
    event.currentTarget.classList.add('pressing');
    setTimeout(() => byId('motion-button').classList.remove('pressing'), tokens.motionMs.base);
    byId('component-status').textContent = 'Press feedback previewed. No app action was performed.';
  });
  const menu = byId('contents-menu');
  const compact = matchMedia('(max-width: 850px)');
  function adjustMenu() { menu.open = !compact.matches; }
  compact.addEventListener('change', adjustMenu);
  adjustMenu();
  document.querySelectorAll('.contents nav a').forEach(link => link.addEventListener('click', () => { if (compact.matches) menu.open = false; }));
  if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) return;
        document.querySelectorAll('.contents nav a').forEach(link => {
          if (link.hash === '#' + entry.target.id) link.setAttribute('aria-current', 'location');
          else link.removeAttribute('aria-current');
        });
      });
    }, {rootMargin: '-15% 0px -70% 0px'});
    document.querySelectorAll('main .chapter').forEach(section => observer.observe(section));
  }
})();
