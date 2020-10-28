const HDS = artifacts.require('HDS')
const expectFail = require('./util/expect-fail')

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

let hds
let admin
let superior

async function deployContracts() {
    accounts = await web3.eth.getAccounts()
    admin = accounts[0]
    superior = accounts[1]
    hds = await HDS.deployed()
}

async function initializeContracts() {
    await deployContracts()
    await hds.initialize(superior)
}

contract('HDS:deploy', accounts => {
    before('deply HDS contract', deployContracts)

    it('should transfer the initial supply tokens to the deployer', async () => {
        const decimals = await hds.decimals()
        assert.equal(decimals, 8)

        const maxSupply = await hds.maxSupply()
        assert.equal(maxSupply, 21000000e8)

        const totalSupply = await hds.totalSupply()
        assert.equal(totalSupply, 4200000e8)

        const adminBalance = await hds.balanceOf(admin)
        assert.equal(adminBalance, 4200000e8)
    })
})

contract('HDS:mint', accounts => {
    before('setup HDS contract', deployContracts)

    it('should fail to mint for the admin account', async () => {
        await expectFail(hds.mint(accounts[2], 1e8))
    })

    it('should be ok minting by the superior', async () => {
        const user = accounts[2]
        await hds.initialize(superior)
        await expectFail(hds.initialize(user))

        const mintAmount = 100e8
        await hds.mint(user, mintAmount, {from: superior})
        assert.equal(await hds.balanceOf(user), mintAmount)
    })

    it('should fail to mint if exceeding the max supply', async () => {
        await expectFail(hds.mint(accounts[2], 21000000e8, { from: superior }))
    })

    it('should fail to mint to zero address', async () => {
        await expectFail(hds.mint(ZERO_ADDRESS, 1e8, { from: superior }))
    })
})

contract('HDS:burn', accounts => {
    const user1 = accounts[2]
    const amount = 100e8

    before('initialize HDS contract', async () => {
        await initializeContracts()
        await hds.transfer(user1, amount, { from: admin })
        assert.equal(await hds.balanceOf(user1), amount)
    })

    it('should fail to burn if balance is insufficient', async () => {
        await expectFail(hds.burn(user1, 101e8, { from: user1 }))
    })

    it('should fail to burn if allowance is insufficient', async () => {
        await hds.approve(admin, 10e8, { from: user1 })
        await expectFail(hds.burn(user1, 11e8, { from: admin }))
    })

    it('should be ok burning if balance is sufficient', async () => {
        await hds.burn(user1, 11e8, { from: user1 })
        assert.equal(await hds.balanceOf(user1), 89e8)
    })

    it('should be ok burning if allowance is sufficient', async () => {
        await hds.burn(user1, 9e8, { from: admin })
        assert.equal(await hds.allowance(user1, admin), 1e8)
        assert.equal(await hds.balanceOf(user1), 80e8)
    })

    it('should fail to burn from zero address', async () => {
        await expectFail(hds.burn(ZERO_ADDRESS, 1e8, { from: user1 }))
    })
})

contract('HDS:transfer', accounts => {
    const user1 = accounts[2]
    const amount = 100e8

    before('initialize HDS contract', async () => {
        await initializeContracts()
        await hds.transfer(user1, amount, { from: admin })
        assert.equal(await hds.balanceOf(user1), amount)

        await hds.approve(admin, 10e8, { from: user1 })
        assert.equal(await hds.allowance(user1, admin), 10e8)
    })

    it('should fail to transfer if balance is insufficient', async () => {
        await expectFail(hds.transfer(admin, 101e8, { from: user1 }))
    })

    it('should fail to transfer if allowance is insufficient', async () => {
        await expectFail(hds.transferFrom(user1, admin, 11e8, { from: admin }))
    })

    it('should be ok to transfer if balance is sufficient', async () => {
        await hds.transfer(admin, 11e8, { from: user1 })
        assert.equal(await hds.balanceOf(user1), 89e8)
    })

    it('should be ok to transfer if allowance is sufficient', async () => {
        await hds.transferFrom(user1, admin, 9e8, { from: admin })
        assert.equal(await hds.allowance(user1, admin), 1e8)
        assert.equal(await hds.balanceOf(user1), 80e8)
    })

    it('should fail to transfer from zero address', async () => {
        await expectFail(hds.transferFrom(ZERO_ADDRESS, user1, 1e8, { from: user1 }))
    })

    it('should fail to transfer to zero address', async () => {
        await expectFail(hds.transfer(ZERO_ADDRESS, 1e8, { from: user1 }))
    })
})

contract('HDS:approve', accounts => {
    before('initialize HDS contract', async () => {
        await initializeContracts()
    })

    it('should fail to approve to zero address', async () => {
        await expectFail(hds.transfer(ZERO_ADDRESS, 1e8, { from: admin }))
    })
})