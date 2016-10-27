$(document).ready(function(){
	// 'Show more' and 'Show less' button rows behavoir
	$(document).on('click', '.show_hide_rows', function(){
		if ($(this).data('table')){
			selector = $("table#"+$(this).data('table')+" tr.hidden_row")
			if ($(this).html() == show_more_label){
				selector.show();
				$(this).html(show_less_label);
			} else {
				selector.hide();
				$(this).html(show_more_label);
			}
		}
	});

	// $('tr.row').hover(function(){
	//   	$('tr.active').removeClass('active');
	//   	$(this).addClass('active');
	// });

	// Highligh row when hover
	$(document).on({
	    mouseenter: function () {
		   	$('tr.active').removeClass('active');
		   	$(this).addClass('active');
	    },
	    // mouseleave: function () {
	    //     $(this).removeClass('active');
	    // }
	}, 'tr.row');
});

function change_metric(metric_option){
	$.ajax({
		url: 'change_metric',
		data: {type: metric_option },
		success: function(data){
			$('#metric_content').html(data['filter']);

			$('.metric_option').removeClass('selected');
			$('#'+metric_option+'_header').addClass('selected');
		}
	})
}

function currency(number){
	return parseFloat(number).toLocaleString('es-ES', {style: 'currency', currency: 'EUR', minimumFractionsDigits: 2, maximumFractionsDigits: 2})
}

function hours(number){
	return parseFloat(number).toLocaleString('es-ES', {style: 'decimal',minimumFractionsDigits: 2, maximumFractionsDigits: 2})+"h"
}

function percent(number){
	return parseFloat(number).toLocaleString('es-ES', {style: 'decimal', maximumFractionsDigits: 2})+" %"
}