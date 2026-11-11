/** Primera letra comparable: sin acentos y en mayúsculas; la Ñ se conserva (es distinta de la N). */
export function firstLetter(value: string): string {
  const c = value.trim().charAt(0);
  if (c === "ñ" || c === "Ñ") return "Ñ";
  return c.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toUpperCase();
}

