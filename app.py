from langchain_groq import ChatGroq
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import strOutputParser

import Streamlit as st
import os
from dotenv import load_dotenv