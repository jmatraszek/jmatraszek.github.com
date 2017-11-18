build: build-blog build-resume

build-blog:
    cobalt build

build-resume:
    mkdir -p build/resume
    hackmyresume BUILD resume/resume.json TO resume.html -t /usr/lib/node_modules/jsonresume-theme-slick/
    mv resume.html build/resume/index.html
    cp resume/jakubmatraszek.jpg build/resume/jakubmatraszek.jpg

clean:
    rm -rf build

# Local Variables:
# mode: makefile
# End:
# vim: set ft=make :
