#r "Newtonsoft.Json"

using System.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Primitives;
using Newtonsoft.Json;
using System.Net.Http;
using System.Net.Http.Headers;

private static readonly HttpClient client = new HttpClient();

public static async Task<IActionResult> Run(HttpRequest req, ILogger log)
{
    client.DefaultRequestHeaders.Add("X-Vault-Token", "s.wS59C22PZF83UMD1pukYWJ4m");
    var responseString = await client.GetStringAsync("http://34.245.5.31:8200/v1/cubbyhole/besharp");
    return new OkObjectResult(responseString);
}