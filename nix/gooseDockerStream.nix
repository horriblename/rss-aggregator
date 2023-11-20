{
  dockerTools,
  goose,
}:
dockerTools.streamLayeredImage {
  name = "horriblename/goose";
  tag = "latest";

  fromImage = dockerTools.pullImage {
    imageName = "alpine";
    imageDigest = "sha256:f3334cc04a79d50f686efc0c84e3048cfb0961aba5f044c7422bd99b815610d3";
    sha256 = "sha256-snYCbJocC3VLcVvOJzlujtHcJAHJHExhxoq/9r3yYvI=";
  };

  contents = [goose];
}
