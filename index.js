exports.handler = async (event) => {
    console.log("Lambda function executed!");
    return { statusCode: 200, body: "Success" };
};
