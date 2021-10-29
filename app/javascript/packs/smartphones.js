import "../stylesheets/application";

$(document).ready(() => {
  $('[data-toggle="tooltip"]').tooltip();
  $('[data-toggle="popover"]').popover();
  $('[data-toggle="carousel"]').carousel();
  $('[data-toggle="dropdown"]').dropdown();

  var modal = document.getElementById("myModal");
  var btn = document.getElementById("phoneBtna");
  var span = document.getElementsByClassName("close")[0];
  btn.onclick = function () {
    modal.style.display = "block";
  };

  span.onclick = function () {
    modal.style.display = "none";
  };

  window.onclick = function (event) {
    if (event.target == modal) {
      modal.style.display = "none";
    }
  };
});
