/** Acción `use:reveal`: anima la entrada del elemento al hacer scroll (respeta reduced-motion). */
export function reveal(node: HTMLElement, delay = 0) {
	if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
	node.classList.add('reveal');
	node.style.transitionDelay = `${delay}ms`;
	const io = new IntersectionObserver((entries) => {
		for (const e of entries) if (e.isIntersecting) { node.classList.add('shown'); io.disconnect(); }
	}, { threshold: 0.15 });
	io.observe(node);
	return { destroy: () => io.disconnect() };
}
