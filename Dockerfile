FROM planitar/base

ADD bin/skydns /usr/bin/

ENTRYPOINT [ "/usr/bin/skydns" ]
CMD "$@"
