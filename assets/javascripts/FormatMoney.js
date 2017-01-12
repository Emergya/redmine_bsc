/*
Copyright (c) 2005, 2008 Marcel Ward

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

// FormatMoney() - returns a string represenation of the numeric value in _amount_ using the given formatting & currency settings.
//
// Preconditions:
//		display_after_decimal_pt >= 0
//		
// Notes:
//		- Usually you'll want significant_after_decimal_pt to be less than or equal to display_after_decimal_pt.
//		- The returned value is automatically rounded to the nearest significant digit.
//		- An invalid (NaN) input amount is replaced by 0 (zero).
//		- If the combined number of visible digits would exceed 21, the digits are replaced by "#".
//		- Negative amounts are fully supported; the (optional) currency symbol is prefixed by a minus.
function FormatMoney(amount, currency_symbol_before,
	currency_symbol_after, thousands_separator, decimal_point,
	significant_after_decimal_pt, display_after_decimal_pt)
{
	// 30JUL2008 MSPW  Fixed minus display by moving this line to the top
	// We need to know how the significant digits will alter our displayed number
	var significant_multiplier = Math.pow(10, significant_after_decimal_pt);

	// Only display a minus if the final displayed value is going to be <= -0.01 (or equivalent)
	var str_minus = (amount * significant_multiplier <= -0.5 ? "-" : "");

	// Sanity check on the incoming amount value
	amount = parseFloat(amount);
	if( isNaN(amount) || Math.LOG10E * Math.log(Math.abs(amount)) +
			Math.max(display_after_decimal_pt, significant_after_decimal_pt) >= 21 )
	{
		return str_minus + currency_symbol_before +
			(isNaN(amount)? "#" : "####################".substring(0, Math.LOG10E * Math.log(Math.abs(amount)))) +
			(display_after_decimal_pt >= 1?
				(decimal_point + "##################".substring(0, display_after_decimal_pt)) : "") + " " +	currency_symbol_after;
	}
	
	// Make +ve and ensure we round up/down properly later by adding half a penny now.
	amount = Math.abs(amount) + (0.5 / significant_multiplier);

	amount *= significant_multiplier;
	
	var str_display = parseInt(
		parseInt(amount) * Math.pow(10, display_after_decimal_pt - significant_after_decimal_pt) ).toString();
			
	// Prefix as many zeroes as is necessary and strip the leading 1
	if( str_display.length <= display_after_decimal_pt )
		str_display = (Math.pow(10, display_after_decimal_pt - str_display.length + 1).toString() +
			str_display).substring(1);
			
	var comma_sep_pounds = str_display.substring(0, str_display.length - display_after_decimal_pt);
	var str_pence = str_display.substring(str_display.length - display_after_decimal_pt);
	
	if( thousands_separator.length > 0 && comma_sep_pounds.length > 3 )
	{
		comma_sep_pounds += ",";

		// We need to do this twice because the first time only inserts half the commas.  The reason is
		// the part of the lookahead ([0-9]{3})+ also consumes characters; embedding one lookahead (?=...)
		// within another doesn't seem to work, so (?=[0-9](?=[0-9]{3})+,)(.)(...) fails to match anything.
		if( comma_sep_pounds.length > 7 )
			comma_sep_pounds = comma_sep_pounds.replace(/(?=[0-9]([0-9]{3})+,)(.)(...)/g, "$2,$3");

		comma_sep_pounds = comma_sep_pounds.replace(/(?=[0-9]([0-9]{3})+,)(.)(...)/g, "$2,$3");

		// Remove the fake separator at the end, then replace all commas with the actual separator
		comma_sep_pounds = comma_sep_pounds.substring(0, comma_sep_pounds.length - 1).replace(/,/g, thousands_separator);
	}

	return str_minus + currency_symbol_before +
		comma_sep_pounds + (display_after_decimal_pt >= 1? (decimal_point + str_pence) : "") + " " + currency_symbol_after;
}