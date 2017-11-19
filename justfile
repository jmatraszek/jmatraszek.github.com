build: build-blog build-resume

build-blog:
    cobalt build

build-resume:
    mkdir -p build/resume
    hackmyresume BUILD resume/resume.json TO resume.html -t /usr/lib/node_modules/jsonresume-theme-slick/
    mv resume.html build/resume/index.html
    cp resume/jakubmatraszek.jpg build/resume/jakubmatraszek.jpg

update-last-modified:
    sed -ri "s/([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2})\:([0-9]{2})\:([0-9]{2})/$(date -u +"%Y-%m-%dT%H:%M:%S")/" resume/resume.json

deploy: update-last-modified build
    git add resume/resume.json
    git commit -m "Bump lastModified in resume.json"
    git push origin source
    cobalt import --branch master
    git checkout master
    git push origin master
    git checkout source


clean:
    rm -rf build

# Local Variables:
# mode: makefile
# End:
# vim: set ft=make :
