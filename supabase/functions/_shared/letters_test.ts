import { assertEquals } from "jsr:@std/assert@1";
import { firstLetter } from "./letters.ts";

Deno.test("firstLetter ignora acentos y mayúsculas", () => {
  assertEquals(firstLetter("  árbol"), "A");
  assertEquals(firstLetter("Élefante"), "E");
  assertEquals(firstLetter("mesa"), "M");
});

Deno.test("firstLetter distingue Ñ de N", () => {
  assertEquals(firstLetter("ñandú"), "Ñ");
  assertEquals(firstLetter("Nutria"), "N");
});
