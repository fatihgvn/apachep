<?php

require __DIR__ . '/system/vendor/autoload.php';
require __DIR__ . '/system/request.php';

use Rain\Tpl;

global $Request, $TemplateEngine;

$config = array(
    "base_url"	=> null,
    "tpl_dir"	=> "theme/",
    "cache_dir"	=> "temp/tpl/",
    "debug"         => true
);

Tpl::configure($config);
Tpl::registerPlugin(new Tpl\Plugin\PathReplace());

$TemplateEngine = new Tpl;

$Request = new Request();

foreach (glob($Request->routes.'/*.php') as $file) {
  include $file;
}
