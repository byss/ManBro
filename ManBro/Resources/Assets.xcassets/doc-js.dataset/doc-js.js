HTML_MAN_SECTIONS = [
	{ section_cls: 'Sh', header_tag: 'h1' },
	{ section_cls: 'Ss', header_tag: 'h2' },
];

function getHeadings (root, level = 0) {
	if (level >= HTML_MAN_SECTIONS.length) { return []; }
	const { section_cls, header_tag } = HTML_MAN_SECTIONS [level];
	const sections = root.querySelectorAll ('section.' + section_cls);
	let result = [];
	for (let i = 0; i < sections.length; i++) {
		const link = sections [i].querySelector ('section > ' + header_tag + ' > a');
		if (link) {
			result.push ({ href: new URL (link.href).hash, name: link.innerText, children: getHeadings (sections [i], level + 1) });
		}
	}
	return result;
}

function goToAnchor (anchor) {
	document.location.hash = anchor;
}
