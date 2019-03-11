const etherlime = require('etherlime');

const MogulDAI = require('./../../build/MogulDAI');
const MovieToken = require('./../../build/MovieToken');

const SQRT = require('./../../contracts/Math/SQRT.json');
const BondingMathematics = require('./../../build/BondingMathematics');

const MogulOrganisation = require('./../../build/MogulOrganisation');

const deployerWallet = accounts[0].signer;
const MOGUL_BANK = accounts[9].signer.address;

const deployer = new etherlime.EtherlimeGanacheDeployer();


let deployMogulOrganization = async (mglDai, movieTokenInstance) => {

    let bondingMathematicsInstance = await deployBondingMath();

    return (await deployer.deploy(MogulOrganisation, {},
        bondingMathematicsInstance.contractAddress,
        mglDai.contractAddress,
        movieTokenInstance.contractAddress,
        MOGUL_BANK));
};

let deployMovieToken = async () => {
    return (await deployer.deploy(MovieToken));
};

let addMovieTokenMinter = async (movieTokenInstance, minterAddr) => {
    await movieTokenInstance.addMinter(minterAddr);
};

let deployTokensSQRT = async (deployerWallet) => {
    let tx = await deployerWallet.sendTransaction({
        data: SQRT.bytecode
    });
    return (await deployerWallet.provider.getTransactionReceipt(tx.hash)).contractAddress;
};

let getMogulToken = async (mogulOrganisationInstance) => {
    return await mogulOrganisationInstance.mogulToken();
    // return (new ethers.Contract(mogulTokenAddress, MogulToken.abi, deployerWallet));
};

let deployBondingMath = async () => {
    let sqrtContractAddress = await deployTokensSQRT(deployerWallet);
    return (await deployer.deploy(BondingMathematics, {}, sqrtContractAddress));
};

let deployMglDai = async () => {
    return (await deployer.deploy(MogulDAI));
};

let mintDAI = async (mogulDAIInstance, to, amount) => {
    await mogulDAIInstance.mint(to, amount)
};

let approveDAI = async (mogulDAIInstance, approver, to, amount) => {
    await mogulDAIInstance.from(approver).approve(to, amount)
};

module.exports = {
    deployTokensSQRT,
    getMogulToken,
    mintDAI,
    approveDAI,
    deployBondingMath,
    deployMogulOrganization,
    deployMglDai,
    addMovieTokenMinter,
    deployMovieToken
};