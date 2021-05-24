LOCAL_CATALOG_PATH = catalog
ALL_CATALOGS = $(LOCAL_CATALOG_PATH) $(shell raco pkg config catalogs)

catalog:
	@echo "Creating local packages catalog..."
	racket -l- pkg/dirs-catalog --check-metadata $(LOCAL_CATALOG_PATH) .

install: catalog
	@echo "Installing clamav-client from local packages catalog..."
	raco pkg install \
		$(foreach catalog, $(ALL_CATALOGS), --catalog $(catalog)) \
		--auto clamav-client

uninstall:
	@echo "Uninstalling clamav-client and auto-installed dependencies..."
	raco pkg remove --auto clamav-client

ci: catalog
	raco pkg install \
		$(foreach catalog, $(ALL_CATALOGS), --catalog $(catalog)) \
		--skip-installed --link --auto clamav-client-test

	raco test --drdr -p clamav-client-test

clean:
	rm -rf $(LOCAL_CATALOG_PATH)
	raco pkg empty-trash
