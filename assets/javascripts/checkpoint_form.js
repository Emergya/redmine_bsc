$(document).ready(function(){
  recalculate_totals();

  $(document).on('keyup', '.checkpoint_cell input', function(event){
    recalculate_totals();
  });
});

function recalculate_totals(){
  total_total = 0;
  total_profiles = $('div[data-total="profile"]');
  $.each(total_profiles, function(index, value){
    total = 0.0;
    profile_cells = $('input[data-profile="'+$(value).data('profile')+'"]');
    $.each(profile_cells, function(i, v){
      total += parseFloat($(v).val());
    });
    total_total += total;
    $(value).html(total.toFixed(2));
    diff = (total-$('div[data-total="old"][data-profile="'+$(value).data('profile')+'"]').text()).toFixed(2);
    $('div[data-total="diff"][data-profile="'+$(value).data('profile')+'"]').html(diff);
  });

  total_years = $('div[data-total="year"]');
  $.each(total_years, function(index, value){
    total = 0.0;
    year_cells = $('input[data-year="'+$(value).data('year')+'"]');
    $.each(year_cells, function(i, v){
      total += parseFloat($(v).val());
    });
    $(value).html(total.toFixed(2));
    diff = (total-$('div[data-total="old"][data-year="'+$(value).data('year')+'"]').text()).toFixed(2);
    $('div[data-total="diff"][data-year="'+$(value).data('year')+'"]').html(diff);
  });


  $('div[data-total="total"]').html(total_total.toFixed(2));
  $('div[data-total="total_diff"]').html((total_total - $('div[data-total="total_old"]').text()).toFixed(2));
}
