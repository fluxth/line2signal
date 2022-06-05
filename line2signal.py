#!/usr/bin/env python3

import os
import sys
import argparse
from getpass import getpass
from dataclasses import dataclass, asdict
import shutil
from pathlib import Path

from os import environ as env
from dotenv import load_dotenv

load_dotenv()

SHOP_URL_PREFIX = "https://store.line.me/stickershop/product/"


@dataclass
class Config:
    username: str
    password: str


def main():
    config = Config(env.get("SIGNAL_USERNAME", ""), env.get("SIGNAL_PASSWORD", ""))
    args = init_arg_parser().parse_args()

    if args.username is not None:
        config.username = args.username

    if args.password is True:
        config.password = getpass("Signal Password: ")

    if len(config.username) == 0 or len(config.password) == 0:
        print("Error: No signal credentials configured", file=sys.stderr)
        exit(1)

    print(f"Using credentials of {config.username}...")

    sticker_id = None

    if args.url.isnumeric():
        sticker_id = int(args.url)

    elif args.url[: len(SHOP_URL_PREFIX)] == SHOP_URL_PREFIX:
        path_segments = args.url[len(SHOP_URL_PREFIX) :].split("/")
        for segment in path_segments:
            if segment.isnumeric():
                sticker_id = int(segment)
                break

    if sticker_id is None:
        print("Error: Could not detect line sticker id", file=sys.stderr)
        exit(1)

    sticker_dir = Path("./stickers") / str(sticker_id)
    if os.path.isdir(sticker_dir):
        i = input(f"Sticker {sticker_id} is already downloaded, overwrite? [y/N]: ")
        if i.lower() == "y":
            shutil.rmtree(sticker_dir)

    print(f"Processing sticker {sticker_id}...")

    sticker_set = get_sticker_set(sticker_id)
    process_stickers(sticker_set)

    print(f"Stickers downloaded to '{sticker_dir}'")


def init_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="line2signal, convert line to signal stickers"
    )

    parser.add_argument("url", help="sticker url or id")

    parser.add_argument(
        "-u",
        "--username",
        help="signal username",
    )

    parser.add_argument(
        "-p",
        "--password",
        action="store_true",
        help="ask for signal password",
    )

    return parser


import requests
import json
from bs4 import BeautifulSoup


@dataclass
class StickerSet:
    id: int
    name: str
    description: str
    image_url: str
    stickers: list


def get_sticker_set(sticker_id: int) -> StickerSet:
    endpoint = SHOP_URL_PREFIX + str(sticker_id) + "/en"
    resp = requests.get(endpoint)

    soup = BeautifulSoup(resp.text, "html.parser")

    metadata_tag = soup.find("script", type="application/ld+json")
    if metadata_tag is None:
        raise Exception()
    metadata = json.loads(metadata_tag.string)

    stickers = []
    sticker_tags = soup.find_all("li", class_="FnStickerPreviewItem")
    for tag in sticker_tags:
        stickers.append(json.loads(tag["data-preview"]))

    return StickerSet(
        id=int(metadata["sku"]),
        name=metadata["name"],
        description=metadata["description"],
        image_url=metadata["image"],
        stickers=stickers,
    )


def process_stickers(sticker_set: StickerSet, download_path: str = "./stickers"):
    base_dir = Path(f"{download_path}/{sticker_set.id}")
    base_dir.mkdir(parents=True, exist_ok=True)

    data_dir = base_dir / "data"
    data_dir.mkdir(parents=True, exist_ok=True)

    metadata_file = base_dir / "metadata.json"
    with open(metadata_file, "w") as f:
        print("Writing metadata...")
        json.dump(asdict(sticker_set), f)

    print(f"Downloading {len(sticker_set.stickers)} stickers...")

    for sticker in sticker_set.stickers:
        if sticker["type"] in ("animation", "animation_sound"):
            url = f"https://stickershop.line-scdn.net/stickershop/v1/sticker/{sticker['id']}/iPhone/sticker_animation@2x.png"
        else:
            url = f"https://stickershop.line-scdn.net/stickershop/v1/sticker/{sticker['id']}/iPhone/sticker@2x.png"

        print(f"Downloading {url}...")

        file = requests.get(url, allow_redirects=True)
        with open(data_dir / f"{sticker['id']}.png", "wb") as f:
            f.write(file.content)


if __name__ == "__main__":
    main()
