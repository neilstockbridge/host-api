
PROJECT=`grep '^Package: ' debian/control | cut -d' ' -f2`
REVISION=`grep '^Version: ' debian/control | cut -d' ' -f2`
ARCH=`grep '^Architecture: ' debian/control | cut -d' ' -f2`
DESTDIR=/tmp/$(PROJECT)_$(REVISION)_$(ARCH)

.SILENT:

all:
	echo run this target as fakeroot otherwise the files will be owned by you
	install --directory $(DESTDIR)/usr/share/$(PROJECT)
	install --mode=0644 --preserve-timestamps json_rpc.rb $(DESTDIR)/usr/share/$(PROJECT)
	install --directory $(DESTDIR)/usr/share/$(PROJECT)/plugins
	install --mode=0644 --preserve-timestamps plugins/* $(DESTDIR)/usr/share/$(PROJECT)/plugins
	install --directory $(DESTDIR)/usr/bin
	install --mode=0755 --preserve-timestamps host-api $(DESTDIR)/usr/bin
	install --directory $(DESTDIR)/etc
	install --mode=0644 --preserve-timestamps host-api.yml $(DESTDIR)/usr/share/$(PROJECT)/host-api.yml
	install --directory --mode=01777 $(DESTDIR)/var/log/host-api
	install --directory $(DESTDIR)/DEBIAN
	install debian/* $(DESTDIR)/DEBIAN
	dpkg-deb --build -Zgzip $(DESTDIR)
	rm -Rf $(DESTDIR)

clean:
#	rm -f  files

