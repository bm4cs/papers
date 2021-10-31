all: clean paper

paper:
	docker run --rm --volume "`pwd`:/data" --user `id -u`:`id -g` pandoc/latex:latest -s -F pandoc-crossref --citeproc --bibliography=paper.bib \
	-V papersize=a4paper -V geometry:margin=1.25in \
	--table-of-contents \
	-s paper.md -o paper.pdf
#	--variable classoption=twocolumn \

clean:
	rm -f *.pdf *.log *.tex

