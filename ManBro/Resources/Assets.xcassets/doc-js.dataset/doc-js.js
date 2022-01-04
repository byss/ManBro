HTML_MAN_SECTIONS = [
	{ section_cls: 'Sh', header_tag: 'h1' },
	{ section_cls: 'Ss', header_tag: 'h2' },
];
// HTML_MAN_TOC = []

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

/*
function tocToggle (btn) {
	if (!btn) {
		const tocDiv = document.getElementById ('html-man-toc');
		tocDiv.className = (tocDiv.className == 'html-man-toc-closed') ? 'html-man-toc-opened' : 'html-man-toc-closed';
		return;
	}

	const parent = btn.parentElement;
	if (parent.className == 'html-man-toc-closed') {
		parent.className = 'html-man-toc-opened';
		btn.innerText = '-';
	} else {
		parent.className = 'html-man-toc-closed';
		btn.innerText = '+';
	}
}

function insertTOCList (root, tocItems) {
	if (!tocItems.length) { return; }
	if (root.tagName.toLowerCase () == 'li') {
		root.className = 'html-man-toc-closed';
		root.innerHTML = '<a onclick="tocToggle (this);">+</a>' + root.innerHTML;
	}
	const ul = document.createElement ('ul');
	for (let i = 0; i < tocItems.length; i++) {
		const item = tocItems [i];
		const li = document.createElement ('li');
		li.innerHTML = '<a onclick="tocToggle ();" href="' + item.href + '">' + item.name + '</a>';
		ul.appendChild (li);
		insertTOCList (li, item.children);
	}
	root.appendChild (ul);
}

function generateTOC () {
	HTML_MAN_TOC = getHeadings (document);
	const titleCell = document.querySelector ('table.head td.head-ltitle');
	const title = titleCell.innerText;
	titleCell.innerHTML = title + '&nbsp;<a onclick="tocToggle ();">TOC</a>';
	const tocDiv = document.createElement ('div');
	tocDiv.id = 'html-man-toc';
	tocDiv.className = 'html-man-toc-closed';
	insertTOCList (tocDiv, HTML_MAN_TOC);
	
	const contentDiv = document.querySelector ('div.manual-text');
	contentDiv.insertBefore (tocDiv, contentDiv.firstElementChild);
}

if (document.readyState == 'loading') {
	document.addEventListener ('DOMContentLoaded', generateTOC);
} else {
	generateTOC ();
}
*/