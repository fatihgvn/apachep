<?php


class Request
{
  public $page = "index";
  public $routes = null;

  public $reqUri = "/";
  public $host = null;
  public $actual = null;
  public $data = [];
  public $http;
  public $method;

  public $breakgets = false;

  const GET = 0;
  const POST = 1;
  const PUT = 2;
  const HEAD = 3;
  const DELETE = 4;
  const PATCH = 5;
  const OPTIONS = 6;

  function __construct()
  {
    $reqUri = explode('?',$_SERVER['REQUEST_URI'])[0];
    $this->reqUri = $reqUri;

    // set http
    $this->http = (object)[
      "content" => null,
      "contentType" => "text/html",
      "code" => 200
    ];

    $this->method = Request::GET;
    switch ($_SERVER['REQUEST_METHOD']) {
      case 'POST': $this->method = Request::POST; break;
      case 'PUT': $this->method = Request::PUT; break;
      case 'HEAD': $this->method = Request::HEAD; break;
      case 'DELETE': $this->method = Request::DELETE; break;
      case 'PATCH': $this->method = Request::PATCH; break;
      case 'OPTIONS': $this->method = Request::OPTIONS; break;
    }

    // get host name
    $this->actual = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http") . "://$_SERVER[HTTP_HOST]";
    $this->host = parse_url($this->actual)['host'];

    $this->routes = __DIR__ . '/routes';

    $this->data = explode('/',$reqUri);
    $this->page = $this->data[0];
    array_shift($this->data);
  }

  public function returnHttp()
  {
    http_response_code($this->http->code);
    header('Content-Type: '.$this->http->contentType);
    print($this->http->content);
  }

  public function transferLocation($uri = null, $code = 301, $forPost = false)
  {
    if(defined('BLOCK_REFERRER') && BLOCK_REFERRER == true) return;

    if($forPost && !empty($post)) return;
    if($uri==null) $uri = $this->actual;

    if(preg_match('/.*\.ico/',$uri)){
      $code = 404;
    }

    http_response_code($code);
    header("Location: $uri");
    die();
  }

  public function get($page, $callback)
  {
    if($this->breakgets) return;

    $reqUri = explode('?',$_SERVER['REQUEST_URI'])[0];

    if (preg_match("/^\/$page\/?$/", $reqUri, $params)) {
      call_user_func_array($callback, [$this, $params, $this->method]);
    }
  }

  public function getIp()
  {
    $client  = $_SERVER['HTTP_CLIENT_IP'] ?? null;
    $forward = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? null;
    $remote  = $_SERVER['REMOTE_ADDR'];
    if(filter_var($client, FILTER_VALIDATE_IP)) $ip = $client;
    elseif(filter_var($forward, FILTER_VALIDATE_IP)) $ip = $forward;
    else $ip = $remote;

    return $ip;
  }
}
