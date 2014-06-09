// Get heroku config values     
module.exports.aws = {
  key: process.env.AWS_KEY,
  secret: process.env.AWS_SECRET,
  urlPrefix : "https://s3-ap-northeast-1.amazonaws.com/butai/"
}