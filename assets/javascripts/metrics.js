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

	// Highligh row when hover
	$(document).on({
	    mouseenter: function () {
		   	$('tr.active').removeClass('active');
		   	$(this).addClass('active');
	    },
	}, 'tr.row');
});

// Show tooltip message on rows with alert
function show_alert_row_tooltip(){
	
}

// load calendars options
function load_calendars(calendar_events){
	// Options for calendars
    calendar_options = {
        firstDay: 1,
        contentHeight: 400,
        header: {
            left: '',
            center: 'title',
            right: ''
        },
	    defaultDate: moment(),
	    theme: true,
	    eventSources: calendar_events,
	    eventRender: function(event, element, view) {
            element.attr('title', event.title);
            if (event.start.month()+1 != view.start.month()+2) return false;
        }
    }

    // Load calendars
    $('#calendar1').fullCalendar(
    	calendar_options
    )

    calendar_options['defaultDate'] = moment().add(1, 'months');
    $('#calendar2').fullCalendar(
    	calendar_options
    )

    calendar_options['defaultDate'] = moment().add(2, 'months');
    $('#calendar3').fullCalendar(
    	calendar_options
    )

    // Show tooltip on event calendars
	$(".fc-title").tooltip();
}

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

// Number formats
function currency(number){
	return parseFloat(number).toLocaleString('es-ES', {style: 'currency', currency: 'EUR', minimumFractionsDigits: 2, maximumFractionsDigits: 2})
}

function hours(number){
	return parseFloat(number).toLocaleString('es-ES', {style: 'decimal',minimumFractionsDigits: 2, maximumFractionsDigits: 2})+"h"
}

function percent(number){
	return parseFloat(number).toLocaleString('es-ES', {style: 'decimal', maximumFractionsDigits: 2})+" %"
}