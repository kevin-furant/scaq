(function () {
  var btn = document.getElementById("tocToggle");
  if (!btn) {
    return;
  }

  btn.addEventListener("click", function () {
    document.body.classList.toggle("toc-open");
  });
})();
