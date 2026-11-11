<script lang="ts">
	import Seo from '#lib/landing/Seo.svelte';
	import Prose from '#lib/landing/Prose.svelte';
	const title = 'Cómo jugar Stop / Basta / Tutifruti: reglas y puntos · Tutifruti AI';
	const description = 'Reglas del juego Stop, Basta o Tutifruti online: cómo sale la letra, cuándo se puede decir STOP, cuántos puntos vale cada respuesta y cómo funcionan las impugnaciones.';
	const jsonld = [{
		'@context': 'https://schema.org', '@type': 'HowTo', name: 'Cómo jugar Tutifruti AI (Stop / Basta)', inLanguage: 'es',
		step: [
			{ '@type': 'HowToStep', name: 'Crea o únete a una sala', text: 'Crea una sala privada y comparte el código TUTI-XXXX, o entra a una sala pública.' },
			{ '@type': 'HowToStep', name: 'Espera la letra', text: 'El juego sortea una letra que no se repite durante la partida.' },
			{ '@type': 'HowToStep', name: 'Completa las categorías', text: 'Escribe una palabra que empiece con esa letra para cada categoría antes de que acabe el tiempo.' },
			{ '@type': 'HowToStep', name: 'Di STOP', text: 'Al completar el 75 % de las categorías puedes decir STOP; los demás tienen unos segundos para terminar.' },
			{ '@type': 'HowToStep', name: 'Validación por IA', text: 'El árbitro de IA valida cada respuesta: 10 puntos si es única, 5 si está repetida, 0 si es inválida.' }
		]
	}];
</script>

<Seo {title} {description} path="/como-jugar" {jsonld} />

<Prose title="Cómo jugar">
	<p>Tutifruti AI es la versión online del juego de toda la vida: <b>Stop</b>, <b>Basta</b>, <b>Tutifruti</b> o <b>Mercado</b>, según dónde lo hayas jugado. La diferencia es que aquí no hace falta revisar hoja por hoja: un árbitro de inteligencia artificial valida cada respuesta y explica su decisión.</p>

	<h2>1. Arma la sala</h2>
	<p>Puedes crear una <b>sala privada</b> y compartir su código (por ejemplo <b>TUTI-4F7K</b>) o el enlace de invitación por WhatsApp. Si no tienes con quién jugar, entra a una <b>sala pública</b> que esté esperando jugadores. Cada sala admite de 2 a 12 personas, y los jugadores de la web y del iPhone juegan juntos.</p>
	<p>Quien crea la sala elige las categorías, el número de rondas (1 a 10), el tiempo por ronda y cuántos segundos quedan después del STOP. Cuando todos marcan <b>Listo</b>, el anfitrión inicia la partida.</p>

	<h2>2. Sale la letra</h2>
	<p>Al empezar cada ronda se sortea una letra que <b>no se repite</b> durante la partida. Por defecto se excluyen las letras difíciles (K, Ñ, Q, W, X, Y, Z); el anfitrión puede incluirlas.</p>

	<h2>3. Completa las categorías</h2>
	<p>Escribe una palabra que empiece con la letra para cada categoría: nombre, país, ciudad, animal, fruta, color, profesión, marca… Tus respuestas se guardan solas mientras escribes, así que no pierdes nada si se corta la conexión.</p>

	<h2>4. ¡STOP!</h2>
	<p>Cuando completas al menos el <b>75 % de las categorías</b> aparece el botón STOP. Al tocarlo, los demás jugadores tienen unos segundos (10 por defecto) para terminar. Si nadie dice STOP, la ronda termina cuando se acaba el tiempo.</p>

	<h2>5. El árbitro de IA valida</h2>
	<p>Para cada respuesta, la IA revisa que empiece con la letra, que pertenezca a la categoría, que sea una palabra real en español y que esté bien escrita. Después reparte los puntos:</p>
	<table>
		<thead><tr><th>Respuesta</th><th>Puntos</th></tr></thead>
		<tbody>
			<tr><td>Válida y única (nadie más la puso)</td><td><b>10</b></td></tr>
			<tr><td>Válida pero repetida con otro jugador</td><td><b>5</b></td></tr>
			<tr><td>Inválida, vacía o dudosa</td><td><b>0</b></td></tr>
		</tbody>
	</table>

	<h2>6. Impugnaciones</h2>
	<p>Cada jugador tiene <b>2 impugnaciones por partida</b>. Si crees que tu respuesta debió ser válida, que no era repetida, o que la de otro jugador no debió contar, toca la respuesta en los resultados, explica por qué y una segunda IA la revisa de forma independiente.</p>

	<h2>7. Siguiente ronda y final</h2>
	<p>La siguiente ronda empieza cuando todos los jugadores conectados marcan <b>Listo</b>. Al terminar la última ronda se muestra la clasificación final; ganas experiencia para subir de nivel y desbloquear logros. ¿Quieres la revancha? Un toque y se juega otra vez con el mismo grupo.</p>

	<p><a href="/jugar">Empieza a jugar ahora</a>, no hace falta registrarse.</p>
</Prose>
