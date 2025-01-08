export function toggleDisplay(target, condition) {
  if (target) {
    target.style.display = condition ? "block" : "none";
  }
}
