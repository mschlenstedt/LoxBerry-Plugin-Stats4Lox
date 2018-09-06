// JavaScript library for Stats4Lox


var populate = function(data, index, prefix) {
		// console.log("Populare called");
		for(var key in data) {
			console.log("key", key, "index", index, "prefix", prefix);
			
			// if (prefix !== "") prefix = prefix+'\\|';
			var name;
//			if(prefix !== undefined) {
//				name = prefix + '\\|' + key;
//			} else {
				name = key;
//			}
			var value = data[key];
			
			if(value === null) 
				continue;
			
			// console.log("name", typeof name, name, "typeof value", typeof value, "value", value);
			
			if( typeof value === 'object' ) {
				// index = key + '\\|';
				// console.log("Recursive call populate with key", key, "index", index, "prefix", prefix);
				var newkey;
				if (index !== undefined) {
					newkey = index + '\\|' + key;
				} else {
					newkey = key;
				}
				populate(data[key], newkey, prefix);
				continue;
			}
			
			var elementid;
			if (index !== undefined) {
				elementid = index+'\\|'+name;
			} else {
				elementid = name;
			}
			if (prefix !== undefined) {
				elementid = prefix + '\\|' + elementid;
			} else {
				elementid = elementid;
			}
			
			element = $('#'+elementid);
			console.log("Selected element", elementid, "index is", index, "name is", name, "object", element);
			
			var type = element.prop('tagName');
			// console.log("Tagname", type);
			

			switch(type ) {
				default:
					element.text(value);
					break;
				
				case 'INPUT':
					if (element.prop('type').toLowerCase() === "checkbox") {
						if (value == 1) {
							element.prop("checked", true);
						} else {
							element.prop("checked", false);
						}
						if(element.attr('data-role') === "flipswitch") 
						{
							element.flipswitch().flipswitch("refresh");
						}
					}
					element.prop("value", value);
					
					break;
				case 'RADIO':
				case 'CHECKBOX':
					for( var j=0; j < element.length; j++ ) {
						element[j].checked = ( value.indexOf(element[j].value) > -1 );
					}
					break;

				<!-- case 'SELECT-MULTIPLE': -->
					<!-- var values = value.constructor == Array ? value : [value]; -->

					<!-- for(var k = 0; k < element.options.length; k++) { -->
						<!-- element.options[k].selected |= (values.indexOf(element.options[k].value) > -1 ); -->
					<!-- } -->
					<!-- break; -->

				case 'SELECT':
				case 'SELECT-ONE':
					$('#'+index+name+' option').filter(function(){ 
						return $(this).prop('value') == value;}).prop('selected', true);
					break;

				<!-- case 'DATE': -->
          				<!-- element.value = new Date(value).toISOString().split('T')[0];	 -->
					<!-- break; -->
			}
		}

	$('input:checkbox').checkboxradio().checkboxradio("refresh");
	$('select').selectmenu().selectmenu("refresh");
	// element.flipswitch().flipswitch("refresh");
	
};
