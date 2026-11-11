<script lang="ts">
	import Seo from '#lib/landing/Seo.svelte';
	import Prose from '#lib/landing/Prose.svelte';
</script>

<Seo title="Política de privacidad · Tutifruti AI" description="Qué datos recoge Tutifruti AI, para qué los usa y cómo puedes borrarlos." path="/privacidad" />

<Prose title="Política de privacidad" updated="11 de noviembre de 2026">
	<p>Esta política explica qué datos trata Tutifruti AI (la app de iPhone y la web <a href="https://tutifruti.site">tutifruti.site</a>), para qué y qué control tienes sobre ellos.</p>

	<h2>Datos que tratamos</h2>
	<ul>
		<li><b>Cuenta:</b> si te registras, tu correo electrónico o el identificador que entrega Iniciar sesión con Apple. Como invitado no pedimos correo: se crea una cuenta anónima temporal.</li>
		<li><b>Perfil:</b> nombre de usuario, avatar, nivel, experiencia, estadísticas, logros e historial de partidas.</li>
		<li><b>Partidas:</b> salas en las que participas, respuestas, puntos, impugnaciones, reacciones y mensajes del chat de la sala.</li>
		<li><b>Social:</b> amistades, enlaces de amistad, notificaciones dentro de la app y reportes o silencios que hagas a otros jugadores.</li>
		<li><b>Técnicos:</b> la última vez que estuviste conectado (para saber quién sigue en la partida) y preferencias como sonidos o vibración, que se guardan en tu dispositivo.</li>
		<li><b>Uso de la web:</b> en tutifruti.site medimos visitas de forma agregada con Google Analytics (páginas vistas, tipo de dispositivo, país aproximado y de dónde llegaste). Usa cookies propias de Google Analytics; no le enviamos tu correo, tu nombre de usuario ni tus respuestas.</li>
	</ul>

	<h2>Para qué los usamos</h2>
	<ul>
		<li>Hacer funcionar el juego: salas, rondas, puntuación, chat, amigos y reconexión.</li>
		<li>Validar respuestas: el texto de las respuestas de cada ronda y sus categorías se envía a un modelo de inteligencia artificial (Google Gemini) para decidir si son válidas. No enviamos tu correo ni tu nombre real.</li>
		<li>Moderar: revisar reportes de comportamiento abusivo.</li>
		<li>Mejorar la web: saber cuántas personas la visitan y qué páginas usan (Google Analytics).</li>
	</ul>
	<p>No vendemos tus datos ni mostramos publicidad personalizada.</p>

	<h2>Proveedores</h2>
	<ul>
		<li><b>Supabase</b>: base de datos, autenticación y funciones del servidor (Estados Unidos).</li>
		<li><b>Google (Gemini API)</b>: validación de respuestas con IA.</li>
		<li><b>Google Analytics</b>: estadísticas de visitas de la web. Puedes bloquearlo con el <a href="https://tools.google.com/dlpage/gaoptout" rel="noopener">complemento de inhabilitación</a> o el bloqueo de rastreadores de tu navegador.</li>
		<li><b>Vercel</b>: alojamiento de la web.</li>
		<li><b>Apple</b>: Iniciar sesión con Apple y compras dentro de la app de iPhone.</li>
	</ul>

	<h2>Conservación y borrado</h2>
	<ul>
		<li>Las cuentas de invitado sin actividad durante 7 días se borran automáticamente, junto con su perfil.</li>
		<li>Puedes borrar tu cuenta cuando quieras desde <b>Perfil → Eliminar cuenta</b>. Se eliminan tu perfil, amistades y datos asociados.</li>
		<li>Los mensajes y respuestas de partidas compartidas pueden conservarse de forma desvinculada de tu cuenta para que el historial de la sala siga siendo coherente.</li>
	</ul>

	<h2>Tus derechos</h2>
	<p>Puedes acceder, corregir o borrar tus datos desde la app, o escribirnos a <a href="mailto:contacto@tutifruti.site">contacto@tutifruti.site</a>. Responderemos en un plazo razonable.</p>

	<h2>Menores</h2>
	<p>Tutifruti AI es apto para todo público, pero no está dirigido a menores de 13 años sin la supervisión de un adulto.</p>

	<h2>Cambios</h2>
	<p>Si cambiamos esta política, actualizaremos la fecha de arriba y, si el cambio es importante, te avisaremos en la app.</p>
</Prose>
