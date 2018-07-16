FROM planitar/base

ADD bin/skydns /usr/bin/

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/bin/skydns"]
CMD "$@"
