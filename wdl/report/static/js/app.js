$(document).ready(function(){
  $('#qc_table').DataTable({
    pageLength: 5,
    responsive: true,
    language: { "url": "https://cdn.datatables.net/plug-ins/1.13.6/i18n/zh.json" }
  });

  $('#map_table').DataTable({
    pageLength: 5,
    responsive: true,
    language: { "url": "https://cdn.datatables.net/plug-ins/1.13.6/i18n/zh.json" }
  });

  $('.nav-header').click(function(){
    var subItems = $(this).next('.nav-sub-items');
    if(subItems.length > 0) {
      $(this).toggleClass('active');
      subItems.slideToggle(300);
      $(this).find('.arrow').toggleClass('fa-chevron-down fa-chevron-up');
    }
  });

  $('a[href^="#"]').click(function(e) {
    e.preventDefault();
    var target = $(this.hash);
    if (target.length) {
      $('html, body').animate({ scrollTop: target.offset().top - 85 }, 500);
    }
  });
});

function zoomPlot(title, src) {
  $('#zoomTitle').text(title);
  $('#zoomDesc').text('');
  if (src) {
    $('#zoomTarget').html('<img src="' + src + '" style="max-width:100%; max-height:70vh;">');
  } else {
    $('#zoomTarget').html('<div style="font-size: 80px; color: #eee;"><i class="fa-solid fa-image"></i></div><div style="font-size: 24px; color: #d64545; font-weight: 800; margin-left:20px;">暂无图片</div>');
  }
  $('#zoomModal').css('display', 'flex').hide().fadeIn(300);
}

function closeZoom() {
  $('#zoomModal').fadeOut(200);
}
