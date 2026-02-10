import $ from 'jquery';
import '../stylesheets/application';

$(document).ready(() => {
  $('[data-toggle="tooltip"]').tooltip();
  $('[data-toggle="popover"]').popover();
  $('[data-toggle="carousel"]').carousel();
  $('[data-toggle="dropdown"]').dropdown();

  const modal = document.getElementById('myModal');
  const btn = document.getElementById('phoneBtna');
  const span = document.getElementsByClassName('close')[0];

  if (btn) {
    btn.addEventListener('click', () => {
      modal.style.display = 'block';
    });
  }

  if (span) {
    span.addEventListener('click', () => {
      modal.style.display = 'none';
    });
  }

  window.addEventListener('click', (event) => {
    if (event.target === modal) {
      modal.style.display = 'none';
    }
  });
});
