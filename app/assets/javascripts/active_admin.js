//= require active_admin/base

(function () {
  function adminResourceFromPath(pathname) {
    var segments = (pathname || "").split("/").filter(Boolean);
    if (segments.length < 2 || segments[0] !== "admin") return null;
    return segments[segments.length - 1];
  }

  function resourceKeyForForm(form) {
    try {
      var actionPath = new URL(form.action, window.location.origin).pathname;
      return adminResourceFromPath(actionPath) || adminResourceFromPath(window.location.pathname);
    } catch (_error) {
      return adminResourceFromPath(window.location.pathname);
    }
  }

  function attributeFromControl(control, field) {
    var name = control.name || "";
    var matched = name.match(/^q\[(.+?)_(?:not_)?(?:i_)?(?:cont|eq|start|end|matches)\]$/);
    if (matched) return matched[1];

    matched = name.match(/^q\[(.+?)\]$/);
    if (matched) return matched[1];

    var predicate = field.querySelector("select[name^='q['][name$='_predicate]']");
    if (!predicate) return null;
    matched = predicate.name.match(/^q\[(.+?)_predicate\]$/);
    return matched ? matched[1] : null;
  }

  function positionMenu(menu, input) {
    var rect = input.getBoundingClientRect();
    menu.style.left = rect.left + "px";
    menu.style.top = rect.bottom + 4 + "px";
    menu.style.width = rect.width + "px";
  }

  function initAdminFilterAutocomplete() {
    function shouldAutocompleteField(attribute, labelText) {
      if (!attribute) return false;
      if (/(email|name)/.test(attribute)) return true;
      if (attribute === "vanity_url") return true;
      return /vanity url/.test(labelText || "");
    }

    var forms = document.querySelectorAll("#sidebar form.filter_form, #sidebar .admin-custom-filter-form");
    forms.forEach(function (form) {
      var resource = resourceKeyForForm(form);
      if (!resource) return;

      var fields = form.querySelectorAll(".filter_form_field");
      fields.forEach(function (field) {
        var label = field.querySelector("label");
        var labelText = (label && label.textContent ? label.textContent : "").toLowerCase();

        if (field.classList.contains("select_and_search")) {
          var firstControl = field.querySelector("input[type='text'], input[type='search'], input[type='email']");
          var firstAttribute = firstControl ? attributeFromControl(firstControl, field) : null;
          if (shouldAutocompleteField(firstAttribute, labelText)) {
            field.classList.add("admin-autocomplete-field");
          }
        }

        var controls = field.querySelectorAll("input[type='text'], input[type='search'], input[type='email']");
        controls.forEach(function (control) {
          if (control.dataset.adminAutocompleteReady === "1") return;
          if (control.id === "sync-job-user-query") return;

          var attribute = attributeFromControl(control, field);
          if (!shouldAutocompleteField(attribute, labelText)) return;

          form.setAttribute("autocomplete", "off");
          control.setAttribute("autocomplete", "new-password");
          control.setAttribute("autocorrect", "off");
          control.setAttribute("autocapitalize", "none");
          control.setAttribute("spellcheck", "false");

          control.dataset.adminAutocompleteReady = "1";

          var menu = document.createElement("div");
          menu.className = "admin-filter-autocomplete-menu";
          menu.hidden = true;
          document.body.appendChild(menu);

          var timeoutId;

          function renderOptions(options) {
            menu.innerHTML = "";
            menu.hidden = options.length === 0;
            positionMenu(menu, control);

            options.forEach(function (option) {
              var item = document.createElement("button");
              item.type = "button";
              item.className = "admin-filter-autocomplete-item";
              item.textContent = option.label;
              item.addEventListener("mousedown", function (event) {
                event.preventDefault();
                control.value = option.label;
                menu.hidden = true;
              });
              menu.appendChild(item);
            });
          }

          control.addEventListener("input", function () {
            clearTimeout(timeoutId);
            timeoutId = setTimeout(function () {
              var query = control.value.trim();
              if (query.length < 2) {
                renderOptions([]);
                return;
              }

              var url = "/admin/filter_autocomplete?resource=" + encodeURIComponent(resource) +
                "&attribute=" + encodeURIComponent(attribute) +
                "&q=" + encodeURIComponent(query);

              fetch(url, { headers: { Accept: "application/json" } })
                .then(function (response) {
                  return response.ok ? response.json() : [];
                })
                .then(function (options) {
                  renderOptions(options);
                })
                .catch(function () {
                  renderOptions([]);
                });
            }, 180);
          });

          control.addEventListener("focus", function () {
            if (menu.children.length > 0) {
              positionMenu(menu, control);
              menu.hidden = false;
            }
          });

          control.addEventListener("blur", function () {
            setTimeout(function () {
              menu.hidden = true;
            }, 120);
          });

          window.addEventListener("resize", function () {
            if (!menu.hidden) positionMenu(menu, control);
          });
          window.addEventListener("scroll", function () {
            if (!menu.hidden) positionMenu(menu, control);
          }, true);
        });
      });
    });
  }

  function initEntityAutocomplete() {
    var inputs = document.querySelectorAll("input[data-autocomplete-url][data-hidden-id-target]");
    if (!inputs.length) return;

    inputs.forEach(function (input) {
      if (input.dataset.entityAutocompleteReady === "1") return;
      input.dataset.entityAutocompleteReady = "1";
      setupEntityAutocomplete(input);
    });
  }

  function initIgdbIdLookup() {
    var inputs = document.querySelectorAll("input[data-igdb-lookup-url][data-igdb-name-target][data-igdb-cache-id-target]");
    if (!inputs.length) return;

    inputs.forEach(function (input) {
      if (input.dataset.igdbLookupReady === "1") return;
      input.dataset.igdbLookupReady = "1";

      var endpoint = input.dataset.igdbLookupUrl;
      var nameField = document.getElementById(input.dataset.igdbNameTarget);
      var cacheIdField = document.getElementById(input.dataset.igdbCacheIdTarget);
      if (!endpoint || !nameField || !cacheIdField) return;

      var timeoutId;
      var lastQuery = "";

      function clearLookup() {
        cacheIdField.value = "";
        nameField.value = "";
      }

      function applyLookup(payload) {
        if (!payload || !payload.id) {
          clearLookup();
          return;
        }

        cacheIdField.value = payload.id;
        nameField.value = payload.label || "";
      }

      function lookupNow() {
        var query = (input.value || "").trim();
        if (!query.length) {
          clearLookup();
          return;
        }
        if (query === lastQuery) return;
        lastQuery = query;

        fetch(endpoint + "?q=" + encodeURIComponent(query), {
          headers: { Accept: "application/json" }
        })
          .then(function (response) {
            return response.ok ? response.json() : {};
          })
          .then(function (payload) {
            applyLookup(payload);
          })
          .catch(function () {
            clearLookup();
          });
      }

      input.addEventListener("input", function () {
        cacheIdField.value = "";
        clearTimeout(timeoutId);
        timeoutId = setTimeout(lookupNow, 220);
      });

      input.addEventListener("blur", lookupNow);
      input.addEventListener("change", lookupNow);
    });
  }

  function initDeleteReturnToPreserver() {
    document.addEventListener("click", function (event) {
      var link = event.target.closest("a[data-method='delete'], a[data-turbo-method='delete']");
      if (!link) return;

      try {
        var current = window.location.pathname + window.location.search;
        var url = new URL(link.getAttribute("href"), window.location.origin);
        if (!url.searchParams.get("return_to")) {
          url.searchParams.set("return_to", current);
          link.setAttribute("href", url.pathname + url.search);
        }
      } catch (_error) {
        // no-op
      }
    });
  }

  function setupEntityAutocomplete(input) {
    var endpoint = input.dataset.autocompleteUrl || input.dataset.syncJobUserAutocompleteUrl;
    var hiddenFieldId = input.dataset.hiddenIdTarget || input.dataset.syncJobUserAutocompleteTarget;
    var hiddenField = document.getElementById(hiddenFieldId);

    if (!endpoint || !hiddenField) return;

    if (input.form) input.form.setAttribute("autocomplete", "off");
    input.setAttribute("autocomplete", "new-password");
    input.setAttribute("autocorrect", "off");
    input.setAttribute("autocapitalize", "none");
    input.setAttribute("spellcheck", "false");

    var menuClass = input.dataset.autocompleteMenuClass || "admin-filter-autocomplete-menu";
    var itemClass = input.dataset.autocompleteItemClass || "admin-filter-autocomplete-item";

    var menu = document.createElement("div");
    menu.className = menuClass;
    menu.hidden = true;
    document.body.appendChild(menu);

    var optionsByLabel = {};
    if (input.value && hiddenField.value) {
      optionsByLabel[input.value] = { id: hiddenField.value, label: input.value };
    }
    var timeoutId;

    function setHiddenFieldFromInput() {
      var selected = optionsByLabel[input.value];
      hiddenField.value = selected ? selected.id : "";
    }

    function renderOptions(options) {
      optionsByLabel = {};
      menu.innerHTML = "";
      menu.hidden = options.length === 0;
      positionMenu(menu, input);

      options.forEach(function (option) {
        optionsByLabel[option.label] = option;
        var item = document.createElement("button");
        item.type = "button";
        item.className = itemClass;
        item.textContent = option.label;
        item.addEventListener("mousedown", function (event) {
          event.preventDefault();
          input.value = option.label;
          hiddenField.value = option.id;
          menu.hidden = true;
        });
        menu.appendChild(item);
      });
    }

    input.addEventListener("input", function () {
      setHiddenFieldFromInput();

      clearTimeout(timeoutId);
      timeoutId = setTimeout(function () {
        var query = input.value.trim();
        if (query.length < 2) {
          renderOptions([]);
          return;
        }

        fetch(endpoint + "?q=" + encodeURIComponent(query), {
          headers: { Accept: "application/json" }
        })
          .then(function (response) {
            return response.ok ? response.json() : [];
          })
          .then(function (options) {
            renderOptions(options);
            setHiddenFieldFromInput();
          })
          .catch(function () {
            renderOptions([]);
          });
      }, 180);
    });

    input.addEventListener("change", setHiddenFieldFromInput);
    input.addEventListener("blur", function () {
      setHiddenFieldFromInput();
      setTimeout(function () {
        menu.hidden = true;
      }, 120);
    });

    input.addEventListener("focus", function () {
      if (menu.children.length > 0) {
        positionMenu(menu, input);
        menu.hidden = false;
      }
    });

    window.addEventListener("resize", function () {
      if (!menu.hidden) positionMenu(menu, input);
    });
    window.addEventListener("scroll", function () {
      if (!menu.hidden) positionMenu(menu, input);
    }, true);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      initEntityAutocomplete();
      initAdminFilterAutocomplete();
      initIgdbIdLookup();
      initDeleteReturnToPreserver();
    });
  } else {
    initEntityAutocomplete();
    initAdminFilterAutocomplete();
    initIgdbIdLookup();
    initDeleteReturnToPreserver();
  }

  document.addEventListener("turbo:load", initEntityAutocomplete);
  document.addEventListener("turbolinks:load", initEntityAutocomplete);
  document.addEventListener("turbo:load", initAdminFilterAutocomplete);
  document.addEventListener("turbolinks:load", initAdminFilterAutocomplete);
  document.addEventListener("turbo:load", initIgdbIdLookup);
  document.addEventListener("turbolinks:load", initIgdbIdLookup);
})();
