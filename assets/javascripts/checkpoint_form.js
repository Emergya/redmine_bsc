$(document).ready(function(){
  console.log(hourly_cost);
  recalculate_totals('hours');
  recalculate_totals('cost');

  $(document).on('keyup', '.checkpoint_cell input', function(event){
    recalculate_totals('hours');
    recalculate_totals('cost');
  });

  $('#checkpoint-form').submit(function(event){
    new_value = $('td[data-total="total"][data-type="cost"]').text();
    old_value = $('td[data-total="total_previous"][data-type="cost"]').text();
    value = (new_value - old_value).toFixed(2);
    percentage = (100*Math.abs((new_value - old_value)/old_value)).toFixed(2)

    if (percentage > 5){
      text = text_checkpoint_confirm.replace('{amount}', value+'€').replace('{percentage}', percentage+'%');
      c = confirm(text);
      return c;
    } else {
      return true
    }
  });
});

function recalculate_totals(type){
  total_total = 0.00;
  total_profiles = $('td[data-total="profile"][data-type="'+type+'"]');
  $.each(total_profiles, function(index, value){
    total = 0.00;
    profile_cells = $('input[data-profile="'+$(value).data('profile')+'"]');
    $.each(profile_cells, function(i, v){
      total += get_value(type, parseFloat($(v).val()), $(v).data('profile'), $(v).data('year'));
    });
    total_total += total;
    $(value).html(total.toFixed(2));
    diff = (total-$('td[data-total="previous"][data-profile="'+$(value).data('profile')+'"][data-type="'+type+'"]').text()).toFixed(2);
    if (diff > -0.01 && diff < 0.01){
      diff = 0.00.toFixed(2);
    }
    $('td[data-total="diff"][data-profile="'+$(value).data('profile')+'"][data-type="'+type+'"]').html(diff);
  });

  total_years = $('td[data-total="year"][data-type="'+type+'"]');
  $.each(total_years, function(index, value){
    total = 0.00;
    year_cells = $('input[data-year="'+$(value).data('year')+'"]');
    $.each(year_cells, function(i, v){
      total += get_value(type, parseFloat($(v).val()), $(v).data('profile'), $(v).data('year'));
    });
    $(value).html(total.toFixed(2));
    diff = (total-$('td[data-total="previous"][data-year="'+$(value).data('year')+'"][data-type="'+type+'"]').text()).toFixed(2);
    if (diff > -0.01 && diff < 0.01){
      diff = 0.00.toFixed(2);
    }
    $('td[data-total="diff"][data-year="'+$(value).data('year')+'"][data-type="'+type+'"]').html(diff);
  });


  $('td[data-total="total"][data-type="'+type+'"] span.value').html(total_total.toFixed(2));
  $('td[data-total="total_diff"][data-type="'+type+'"] span.value').html((total_total - $('td[data-total="total_previous"][data-type="'+type+'"] span.value').text()).toFixed(2));
}

function get_value(type, hours, profile, year){
  if (type == "cost") {
    return hours*hourly_cost[year][profile];
  } else if (type == "hours") {
    return hours;
  }
}