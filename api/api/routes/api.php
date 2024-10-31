<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/**
Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');
*/

// Returns a list of available locations.
Route::get('/lunch/locations', function () {
    return;
});

// Returns a list of year + weeks that are available for a location.
Route::get('/lunch/selection/{location}', function (int $location) {
    return;
});

// Returns today's menu.
Route::get('/lunch/menu/{location}', function (int $location) {
    return;
});

// Returns the weekmenu for a given location and year + week.
Route::get('/lunch/menu/{location}/{year}/{week}', function (int $location, int $year, int $week) {
    return;
});

// Returns the asset for a dish in today's menu.
Route::get('/lunch/asset/{location}/{type}', function (int $location, int $type) {
    return 'daymenu';
});

// Returns the asset for a dish in the weekmenu.
Route::get('/lunch/asset/{location}/{year}/{week}/{day}/{type}', function (int $location, int $year, int $week, string $type) {
    return 'weekmenu';
});
