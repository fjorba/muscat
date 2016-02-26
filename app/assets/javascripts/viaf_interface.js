var show_viaf_actions = function () {
	var $viaf_table = $("#viaf_table");

	$("#viaf-sidebar").click(function(){
		marc_editor_show_panel("viaf-form");
	});

	$viaf_table.delegate('.data', 'click', function() {
		_update_form($(this).data("viaf"));
		marc_editor_show_panel("marc_editor_panel");
	});

	/**
	* Update form following these rules:
	* if tag in protected fields: only update if new
	* else: add other tags (new and append)
	* never update fields if not new
	* OPTIMIZE use external conf
	* OPTIMIZE too much and complex logic here
	*/
	function _update_form(data){
		protected_fields = ['100']
		tags = data["fields"]
		for (t in tags){
			datafield = tags[t]
			if (!($.inArray(datafield.tag, protected_fields))){
				if (/\/new#$/.test(self.location.href)){
					_update_marc_tag(datafield.tag, marc_json_get_tags(data, datafield.tag)[0])
				}
				else{
					continue
				}
				continue
			}
			if (_size_of_marc_tag(datafield.tag) == 0){
				_new_marc_tag(datafield.tag, marc_json_get_tags(data, datafield.tag)[0])
			}
			else{
				if (_marc_tag_is_empty(datafield.tag)){
					_edit_marc_tag(datafield.tag, marc_json_get_tags(data, datafield.tag)[0])
				}
				else{
					_append_marc_tag(datafield.tag, marc_json_get_tags(data, datafield.tag)[0])
				}
			}
		}
	}

	$("#viaf_button").click(function(){
		$viaf_table.html("");
		var term = $("#viaf_input").val();
		$.ajax({
			type: "GET",
			url: "/admin/people/viaf.json?viaf_input="+term,
			beforeSend: function() {
				$('#loader').show();
			},
			complete: function(){
				$('#loader').hide();
			},
			success: function(data){
				var result = (JSON.stringify(data));
				drawTable(data);
			}
		});
	});

	function drawTable(data) {
		for (var i = 0; i < data.length; i++) {
			drawRow(data[i]);
		}
	}

	function drawRow(rowData) {
		var id = marc_json_get_tags(rowData, "001")[0].content;
		var tag100 = marc_json_get_tags(rowData, "100")[0]
		var row = $("<tr />")
		$viaf_table.append(row); 
		row.append($("<td><a target=\"_blank\" href=\"http://viaf.org/viaf/" + id + "\">" + id + "</a></td>"));
		row.append($("<td>" + tag100["a"] + "</td>"));
		row.append($("<td>" + (tag100["d"] ? tag100["d"] : "") + "</td>"));
		row.append($("<td>" + tag100["0"] + "</td>"));
		row.append($('<td><a class="data" href="#" data-viaf=\'' + JSON.stringify(rowData) + '\'>Übernehmen</a></td>'));
	}
};

function _update_marc_tag(target, data) {
	block = $(".marc_editor_tag_block[data-tag='" + target + "']")
	for (code in data){
		subfield = block.find(".subfield_entry[data-tag='" + target + "'][data-subfield='" + code + "']").first()
		subfield.val(data[code]);
		subfield.css("background-color", "#ffffb3");
	}
}

function _new_marc_tag(target, data) {
	field = $(".tag_placeholders[data-tag='"+ target +"']")
	placeholder = field.parents(".tag_group").children(".tag_placeholders_toplevel").children(".tag_placeholders")
	parent_dl = field.parents(".tag_group").children(".marc_editor_tag_block");
	new_dt = placeholder.clone();
	for (code in data){
		subfield = new_dt.find(".subfield_entry[data-tag='" + target + "'][data-subfield='" + code + "']").first()
		subfield.val(data[code]);
		subfield.css("background-color", "#ffffb3");
	}
	new_dt.toggleClass('tag_placeholders tag_toplevel_container');
	parent_dl.append(new_dt);
	new_dt.show();
	new_dt.parents(".tag_group").children(".tag_empty_container").hide();
}

function _append_marc_tag(target, data) {
	block = $(".marc_editor_tag_block[data-tag='" + target + "']")
	placeholder = block.parents(".tag_group").children(".tag_placeholders_toplevel").children(".tag_placeholders");
	new_dt = placeholder.clone()
	for (code in data){
		subfield = new_dt.find(".subfield_entry[data-tag='" + target + "'][data-subfield='" + code + "']").first()
		subfield.val(data[code]);
		subfield.css("background-color", "#ffffb3");
	}
	new_dt.toggleClass('tag_placeholders tag_toplevel_container');
	block.append(new_dt)
	new_dt.show()
}


function _size_of_marc_tag(tag){
	fields = $(".tag_toplevel_container[data-tag='"+ tag +"']")
	return fields.size()		
}

function _marc_tag_is_empty(tag){
	block = $(".marc_editor_tag_block[data-tag='" + tag + "']")
	subfields = block.find("input.subfield_entry[data-tag='" + tag + "']")
	for (var i = 0; i < subfields.length; i++){
		if (subfields[i].value!=""){
			return false
		}
	}
	return true
}

$(document).ready(show_viaf_actions);


