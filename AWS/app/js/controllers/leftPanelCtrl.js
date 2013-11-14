/**
 * Left Panel Module LeftPanelCtrl - Manages the model for the left panel.
 */
angular.module("aws.leftPanel", []).controller("LeftPanelCtrl",
		function($scope, $location, queryService, $q) {
			
			$scope.isActive = function(route) {
				return route == $location.path();
			};
			
			$scope.queryObject = angular.toJson(queryService.queryObject, true);

			
			$scope.$watch(function () {
				return queryService.queryObject;
			},function() {
				$scope.queryObject = angular.toJson(queryService.queryObject, true);
			}, true);
			
			$scope.$watch(function() { return $scope.queryObject }, function() {
				queryService.queryObject = angular.fromJson($scope.queryObject);
			}, true);
			
			$scope.shouldShow = false;
				var setCount = function(res) {
				$scope.shouldShow = res;
			};
			aws.addBusyListener(setCount);

		});

function saveJSON(query) {
	var blob = new Blob([ JSON.stringify(query, undefined, 2) ], {
		type : "text/plain;charset=utf-8"
	});
	saveAs(blob, "QueryObject.json");
}