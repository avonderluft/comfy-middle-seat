import jQuery from "jquery";

if (!RedactorPlugins) var RedactorPlugins = {};

(function ($) {
  RedactorPlugins.imagemanager = function () {
    return {
      init: function () {
        if (!this.opts.imageManagerJson) return;

        this.modal.addCallback("image", this.imagemanager.load);
      },
      load: function () {
        var $modal = this.modal.getModal();

        this.modal.createTabber($modal);
        this.modal.addTab(1, "Upload", "active");
        this.modal.addTab(2, "Choose");

        $("#redactor-modal-image-droparea").addClass(
          "redactor-tab redactor-tab1"
        );

        var $box = $(
          '<div id="redactor-image-manager-box" style="overflow: auto; height: 300px;" class="redactor-tab redactor-tab2">'
        ).hide();
        var $search = $(
          '<input type="search" class="form-control" placeholder="Search images" style="margin-bottom: 10px;">'
        );
        var $results = $("<div>");
        $box.append($search, $results);
        $modal.append($box);

        var request;
        var timer;
        var loadImages = $.proxy(function () {
          if (request) request.abort();
          request = $.ajax({
            dataType: "json",
            cache: false,
            data: { q: $search.val() },
            url: this.opts.imageManagerJson,
            success: $.proxy(function (data) {
              $results.empty();
              $.each(
                data,
                $.proxy(function (key, val) {
                  // title
                  var thumbtitle = "";
                  if (typeof val.title !== "undefined") thumbtitle = val.title;

                  var img = $(
                    '<img src="' +
                      val.thumb +
                      '" rel="' +
                      val.image +
                      '" title="' +
                      thumbtitle +
                      '" style="width: 100px; height: 75px; cursor: pointer;" />'
                  );
                  $results.append(img);
                  $(img).click($.proxy(this.imagemanager.insert, this));
                }, this)
              );
            }, this),
          });
        }, this);

        $search.on("input", function () {
          clearTimeout(timer);
          timer = setTimeout(loadImages, 250);
        });
        loadImages();
      },
      insert: function (e) {
        this.image.insert(
          '<img src="' +
            $(e.target).attr("rel") +
            '" alt="' +
            $(e.target).attr("title") +
            '">'
        );
      },
    };
  };
})(jQuery);
