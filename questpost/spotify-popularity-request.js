var artistId = args[0]

const clientIdAndSecret = secrets.clientId + ':' + secrets.clientSecret;
const base64Encoded = Buffer.from(clientIdAndSecret).toString('base64');


const oauthTokenResponse = await Functions.makeHttpRequest({
    url: "https://accounts.spotify.com/api/token",
    method: "POST",
    headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization": 'Basic ' + base64Encoded,
},
    data: { 
        "grant_type": "client_credentials", 
    }
})

if (!oauthTokenResponse.error) {
    console.log(oauthTokenResponse.data.access_token);
    const artistPopularityResponse = await Functions.makeHttpRequest({
        url: `https://api.spotify.com/v1/artists/${artistId}`,
        headers: {
            'Authorization': `Bearer ${oauthTokenResponse.data["access_token"]}`,
            'Content-Type': 'application/json',
        }
    })
    return Functions.encodeUint256(artistPopularityResponse.data["popularity"])
}
else {
    console.log("Oauth error!");
    console.log(oauthTokenResponse);
}
