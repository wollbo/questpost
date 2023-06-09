## QuestPost
QuestPost is a platform that connects task completion to verifiable APIs and smart contracts, creating a censorship-resistant and trust-minimized way for individuals to complete tasks for money. By reducing the friction and disputes traditionally associated with tasks such as digital marketing or search engine optimization, QuestPost offers a unique approach to earning money online.



![questpost logo](questpost/home/static/images/android-chrome-512x512.png)

## Table of Contents

- Installation
- Usage
- Contributing
- License

### Installation
The project dependencies are defined in pyproject.toml. Create a new virtual environment standing at the root of the repository using 

#### Linux
```
python -m venv venv --upgrade-deps
source venv/bin/activate
pip3 install -e
```

#### Windows
```
python -m venv venv --upgrade-deps
venv/Scripts/activate
pip install -e
```


In order to run the website locally you need to create an .env file at the root of the repository with the fields
```
DATABASE_URL
DATABASE_HOST
DATABASE_PORT
DATABASE_USERNAME
DATABASE_PASSWORD
DATABASE_NAME
DATABASE_SSLMODE
MORALIS_API_KEY
CONTRACT_ADDRESS = 0x0015bE3497E390aaAa38c1bcFf044c92672Dbb2d
```
Initialize the database fields by running `python manage.py migrate`
and run the website through the command `python manage.py runserver`

### Usage

A live deployment of the platform is available at [questpost.xyz](https://www.questpost.xyz)

### License

MIT
