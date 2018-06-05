$(document).ready(function(){
  console.log(hourly_cost);
  recalculate_totals();

  $(document).on('keyup', '.checkpoint_cell input', function(event){
    recalculate_totals();
  });
});

function recalculate_totals(){
  total_total = 0.00;
  total_profiles = $('td[data-total="profile"]');
  $.each(total_profiles, function(index, value){
    total = 0.00;
    profile_cells = $('input[data-profile="'+$(value).data('profile')+'"]');
    $.each(profile_cells, function(i, v){
      total += get_cost(parseFloat($(v).val()), $(v).data('profile'), $(v).data('year'));
    });
    total_total += total;
    $(value).html(total.toFixed(2));
    diff = (total-$('td[data-total="previous"][data-profile="'+$(value).data('profile')+'"]').text()).toFixed(2);
    if (diff > -0.01 && diff < 0.01){
      diff = 0.00.toFixed(2);
    }
    $('td[data-total="diff"][data-profile="'+$(value).data('profile')+'"]').html(diff);
  });

  total_years = $('td[data-total="year"]');
  $.each(total_years, function(index, value){
    total = 0.00;
    year_cells = $('input[data-year="'+$(value).data('year')+'"]');
    $.each(year_cells, function(i, v){
      total += get_cost(parseFloat($(v).val()), $(v).data('profile'), $(v).data('year'));
    });
    $(value).html(total.toFixed(2));
    diff = (total-$('td[data-total="previous"][data-year="'+$(value).data('year')+'"]').text()).toFixed(2);
    if (diff > -0.01 && diff < 0.01){
      diff = 0.00.toFixed(2);
    }
    $('td[data-total="diff"][data-year="'+$(value).data('year')+'"]').html(diff);
  });


  $('td[data-total="total"]').html(total_total.toFixed(2));
  $('td[data-total="total_diff"]').html((total_total - $('td[data-total="total_previous"]').text()).toFixed(2));
}

function get_cost(hours, profile, year){
  console.log(hours);
  console.log(profile);
  console.log(year);
  return hours*hourly_cost[year][profile];
}
