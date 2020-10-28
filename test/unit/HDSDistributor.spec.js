const { advanceBlock } = require('./util/advance')
const expectThrow = require('./util/expect-throw')
const HDS = artifacts.require('HDS')
const HDSDistributor = artifacts.require('HDSDistributor')

contract('HDSDistributor:initialize', accounts => {
    it('', async () => {
        let b = await web3.eth.getBlock('latest')
        console.log(b)
        await advanceBlock()
        b = await web3.eth.getBlock('latest')
        console.log(b)
    })
})