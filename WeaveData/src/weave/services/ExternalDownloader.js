/* ***** BEGIN LICENSE BLOCK *****
 *
 * This file is part of the Weave API.
 *
 * The Initial Developer of the Weave API is the Institute for Visualization
 * and Perception Research at the University of Massachusetts Lowell.
 * Portions created by the Initial Developer are Copyright (C) 2008-2012
 * the Initial Developer. All Rights Reserved.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 * 
 * ***** END LICENSE BLOCK ***** */

/**
 * The code below assumes it is being executed within a function(){} where the 'weave' variable is defined.
 * @namespace weave
 * @description The Weave instance.
 * @private
 */

/**
 * @param {string} id
 * @param {string} url
 */
weave.ExternalDownloader_get = function (id, url) {
	var handled = false;
	var request = new XMLHttpRequest();
	request.open("GET", url, true);
	request.responseType = "blob";
	request.onload = function(event) {
		var blob = request.response;
		var reader = new FileReader();
		reader.onloadend = function(event) {
			var url = reader.result;
			var base64data = url.split(',').pop();
			weave.ExternalDownloader_result(id, base64data);
			handled = true;
		};
		reader.onerror = function(event) {
			weave.ExternalDownloader_fault(id);
			handled = true;
		};
		reader.readAsDataURL(blob);
	};
	request.onerror = function(event) {
		if (!handled)
			weave.ExternalDownloader_fault(id);
		handled = true;
	}
	request.onreadystatechange = function() {
		if (request.readyState == 4 && request.status != 200)
		{
			setTimeout(
				function() {
					if (!handled)
						weave.ExternalDownloader_fault(id);
					handled = true;
				},
				1000
			);
		}
	};
	request.send();
};