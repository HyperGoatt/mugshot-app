/* Reference copy stays tied to the same source-derived brand contract. */
(() => {
  const brand = window.MUGSHOT_BRAND?.brand;
  if (!brand) return;
  document.querySelectorAll('[data-copy]').forEach(element => {
    const sample = brand.copy.find(item => item.id === element.dataset.copy);
    if (sample) element.textContent = sample.text;
  });
})();
