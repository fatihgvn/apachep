<?php

global $Request, $TemplateEngine;

$Request->get('(|index)', function($client, $params, $method)
{
  global $TemplateEngine;
  if($method == Request::GET){

    echo $TemplateEngine->draw("header");
    echo $TemplateEngine->draw("index");
    echo $TemplateEngine->draw("footer");

  }
});
