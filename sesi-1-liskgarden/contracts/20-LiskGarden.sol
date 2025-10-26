// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract LiskGarden {
    enum GrowthStage {
        SEED, 
        SPROUT, 
        GROWING, 
        BLOOMING
    }

    struct Plant {
        uint256 id;
        address owner;
        GrowthStage stage;
        uint256 plantedDate;
        uint256 lastWatered;
        uint8 waterLevel;
        bool exists;
        bool isDead;
    }

    mapping(uint256 => Plant) public plants;
    mapping(address => uint256[]) public userPlants;
    uint256 public plantCounter;
    address public owner;
    uint256 public constant PLANT_PRICE = 0.001 ether;
    uint256 public constant HARVEST_REWARD = 0.003 ether;
    uint256 public constant STAGE_DURATION = 1 minutes;
    uint256 public constant WATER_DEPLETION_TIME = 30 seconds;
    uint8 public constant WATER_DEPLETION_RATE = 2;
    uint8 public constant MAX_WATER_LEVEL = 100;

    event PlantSeeded(address indexed owner, uint256 indexed plantId);
    event PlantWatered(uint256 indexed plantId, uint8 newWaterLevel);
    event PlantHarvested(uint256 indexed plantId, address indexed owner, uint256 reward);
    event StageAdvanced(uint256 indexed plantId, GrowthStage newStage);
    event PlantDied(uint256 indexed plantId);

    constructor() {
        owner = msg.sender;
    }

    function deposit() public payable {
        require(msg.sender == owner);
    }

    function plantSeed() external payable returns (uint256) {
        require(msg.value >= PLANT_PRICE);

        plantCounter++;
        
        plants[plantCounter] =  Plant({
            id: plantCounter,
            lastWatered: block.timestamp,
            waterLevel: MAX_WATER_LEVEL,
            stage: GrowthStage.SEED,
            exists: true,
            isDead: false,
            plantedDate: block.timestamp,
            owner: msg.sender
        });
        
        userPlants[msg.sender].push(plantCounter);
        emit PlantSeeded(msg.sender, plantCounter);
        return plantCounter;
    }

    function calculateWaterLevel(uint256 plantId) public view returns (uint8) {
        Plant storage plant = plants[plantId];

        if(!plant.exists || plant.isDead) return 0;

        uint256 timeSinceWatered = block.timestamp - plant.lastWatered;
        uint256 depletionIntervals = timeSinceWatered / WATER_DEPLETION_TIME;
        uint8 waterLost = uint8(depletionIntervals) * WATER_DEPLETION_RATE;

        if (waterLost >= plant.waterLevel) return 0;

        return plant.waterLevel - waterLost;
    }

    function updateWaterLevel(uint256 plantId) internal {
        Plant storage plant = plants[plantId];

        plant.waterLevel = calculateWaterLevel(plantId);
        
        if (plant.waterLevel == 0 && !plant.isDead) {
            plant.isDead = true;
            emit PlantDied(plantId);
        }
    }

    function waterPlant(uint256 plantId) external {
        Plant storage plant = plants[plantId];

        require(plant.exists, "Plant does not exist");
        require(owner == msg.sender, "Not your plant");
        require(!plant.isDead, "Plant dead already");

        plant.waterLevel = 100;
        plant.lastWatered = block.timestamp;

        emit PlantWatered(plantId, 100);
        updatePlantStage(plantId);
    }

    function updatePlantStage(uint256 plantId) public {
        Plant storage plant = plants[plantId];
        
        require(plant.exists, "Plant does not exist");
        
        updateWaterLevel(plantId);

        if (plant.isDead) {
            return;
        }

        uint256 timeSincePlanted = block.timestamp - plant.plantedDate;
        GrowthStage oldStage = plant.stage;

        if (timeSincePlanted >= 3 minutes) {
            plant.stage = GrowthStage.BLOOMING;
        } else if (timeSincePlanted >= 2 minutes) {
            plant.stage = GrowthStage.GROWING;
        } else if (timeSincePlanted >= 1 minutes) {
            plant.stage = GrowthStage.SPROUT;
        }

        if(plant.stage != oldStage) emit StageAdvanced(plantId, plant.stage);
    }

    function harvestPlant(uint256 plantId) external {
        Plant storage plant = plants[plantId];

        require(plant.exists, "Plant does not exist");
        require(msg.sender == plant.owner, "Not your plant");
        require(!plant.isDead, "Plant dead already");

        updatePlantStage(plantId);

        require(plant.stage == GrowthStage.BLOOMING, "Not ready for harvest"); 
        
        plant.exists = false;
        emit PlantHarvested(plantId, plant.owner, HARVEST_REWARD);

        (bool success, ) = payable(msg.sender).call{value: HARVEST_REWARD}("");
        require(success, "Transfer failed");
    }

    function getPlant(uint256 plantId) external view returns (Plant memory) {
        Plant memory plant = plants[plantId];
        plant.waterLevel = calculateWaterLevel(plantId);
        return plant;
    }

    function getUserPlants(address user) external view returns (uint256[] memory) {
        return userPlants[user];
    }

    function withdraw() external {
        require(msg.sender == owner, "Bukan owner");
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Transfer gagal");
    }

    receive() external payable {}
}
