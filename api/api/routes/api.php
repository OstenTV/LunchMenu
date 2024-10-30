<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/**
Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');
 */

 Route::redirect('/status', '/up');

 Route::get('/hello', function () {
    return 'Hello, World!';
});